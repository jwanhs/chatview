import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/models.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'reaction_widget.dart';
import 'share_icon.dart';
import 'package:image/image.dart' as img;

class VideoMessageView extends StatefulWidget {
  const VideoMessageView({
    Key? key,
    required this.message,
    required this.isMessageBySender,
    this.videoMessageConfig,
    this.messageReactionConfig,
    this.highlightVideo = false,
    this.highlightScale = 1.2,
  }) : super(key: key);

  /// Provides message instance of chat.
  final Message message;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides configuration for video message appearance.
  final VideoMessageConfiguration? videoMessageConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents flag of highlighting video when user taps on replied video.
  final bool highlightVideo;

  /// Provides scale of highlighted video when user taps on replied video.
  final double highlightScale;

  String get videoUrl => message.mediaUrl;

  Widget get iconButton => ShareIcon(
        shareIconConfig: videoMessageConfig?.shareIconConfig,
        mediaUrl: videoUrl,
      );

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoMessageView> {
  Uint8List? _thumbnailBytes;
  bool _isThumbnailLoading = true;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    if (widget.message.mediaThumbnailUrl != null) {
      _getNetworkImageAspectRatio();
    } else {
      _generateThumbnail();
    }
  }

  Future<void> _getNetworkImageAspectRatio() async {
    final imageProvider = CachedNetworkImageProvider(widget.message.mediaThumbnailUrl!);
    final completer = Completer<ImageInfo>();
    final listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        completer.complete(info);
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        completer.completeError(error, stackTrace);
      },
    );

    imageProvider.resolve(const ImageConfiguration()).addListener(listener);

    try {
      final imageInfo = await completer.future;
      final aspectRatio = imageInfo.image.width / imageInfo.image.height;
      setState(() {
        _aspectRatio = aspectRatio;
        _isThumbnailLoading = false;
      });
    } catch (e) {
      // Handle error, set a default aspect ratio or hide the thumbnail
      setState(() {
        _isThumbnailLoading = false;
        // Optionally, set a default aspect ratio
        _aspectRatio = 16 / 9;
      });
    }
  }

  Future<void> _generateThumbnail() async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.PNG,
        maxWidth: 128, // specify the width of the thumbnail
        quality: 25,
      );

      if (uint8list != null) {
        final image = img.decodeImage(uint8list);
        if (image != null) {
          setState(() {
            _thumbnailBytes = uint8list;
            _aspectRatio = image.width / image.height;
            _isThumbnailLoading = false;
          });
          return;
        }
      }

      // If decoding fails, fallback
      setState(() {
        _isThumbnailLoading = false;
      });
    } catch (e) {
      // Handle error or fallback
      setState(() {
        _isThumbnailLoading = false;
      });
    }
  }

  void _openVideoPlayer() {
    if (widget.videoMessageConfig != null &&
        widget.videoMessageConfig!.onVideoOpened != null) {
      widget.videoMessageConfig!.onVideoOpened!(widget.videoUrl);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              FullScreenVideoPlayer(videoUrl: widget.videoUrl),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: widget.isMessageBySender
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        if (widget.isMessageBySender &&
            !(widget.videoMessageConfig?.hideShareIcon ?? false))
          widget.iconButton,
        Stack(
          children: [
            GestureDetector(
              onTap: _openVideoPlayer,
              child: Transform.scale(
                scale: widget.highlightVideo ? widget.highlightScale : 1.0,
                alignment: widget.isMessageBySender
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  padding:
                      widget.videoMessageConfig?.padding ?? EdgeInsets.zero,
                  margin: widget.videoMessageConfig?.margin ??
                      EdgeInsets.only(
                        top: 6,
                        right: widget.isMessageBySender ? 6 : 0,
                        left: widget.isMessageBySender ? 0 : 6,
                        bottom: widget.message.reaction.reactions.isNotEmpty
                            ? 15
                            : 0,
                      ),
                  // Remove fixed height and width
                  constraints: BoxConstraints(
                    maxWidth: 300, // Set your desired max width
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black12,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _aspectRatio != null
                        ? AspectRatio(
                            aspectRatio: _aspectRatio!,
                            child: _getThumbNail(),
                          )
                        : _getThumbNail(),
                  ),
                ),
              ),
            ),
            if (widget.message.reaction.reactions.isNotEmpty)
              ReactionWidget(
                isMessageBySender: widget.isMessageBySender,
                reaction: widget.message.reaction,
                messageReactionConfig: widget.messageReactionConfig,
              ),
          ],
        ),
        if (!widget.isMessageBySender &&
            !(widget.videoMessageConfig?.hideShareIcon ?? false))
          widget.iconButton,
      ],
    );
  }

  Widget _getThumbNail() {
  if (widget.message.mediaThumbnailUrl != null) {
    return CachedNetworkImage(
      imageUrl: widget.message.mediaThumbnailUrl!,
      imageBuilder: (context, imageProvider) {
        // You can use ImageProvider to get the image dimensions if needed
        // For simplicity, assume a standard aspect ratio or fetch dynamically
        return Stack(
          fit: StackFit.expand,
          children: [
            Image(image: imageProvider, fit: BoxFit.cover),
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 50,
              ),
            ),
          ],
        );
      },
      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 50,
        ),
      ),
    );
  }

  return _isThumbnailLoading
      ? const Center(child: CircularProgressIndicator())
      : _thumbnailBytes != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  _thumbnailBytes!,
                  fit: BoxFit.cover,
                ),
                const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 50,
                  ),
                ),
              ],
            )
          : const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 50,
              ),
            );
}


}

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const FullScreenVideoPlayer({Key? key, required this.videoUrl})
      : super(key: key);

  @override
  _FullScreenVideoPlayerState createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isControllerInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (widget.videoUrl.isUrl) {
      _controller = VideoPlayerController.network(widget.videoUrl);
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    }

    await _controller.initialize();
    setState(() {
      _isControllerInitialized = true;
    });
    _controller.play();
    _isPlaying = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Video'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: _isControllerInitialized
            ? GestureDetector(
                onTap: _togglePlayPause,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (!_isPlaying)
                      Icon(
                        Icons.play_arrow,
                        color: Colors.white70,
                        size: 100,
                      ),
                  ],
                ),
              )
            : CircularProgressIndicator(),
      ),
    );
  }
}
