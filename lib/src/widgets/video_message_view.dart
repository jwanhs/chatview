import 'dart:io';
import 'dart:typed_data';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/models.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'reaction_widget.dart';
import 'share_icon.dart';

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

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.PNG,
        maxWidth:
            128, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
        quality: 25,
      );
      setState(() {
        _thumbnailBytes = uint8list;
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenVideoPlayer(videoUrl: widget.videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          widget.isMessageBySender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (widget.isMessageBySender &&
            !(widget.videoMessageConfig?.hideShareIcon ?? false))
          widget.iconButton,
        Stack(
          children: [
            GestureDetector(
              onTap: _isThumbnailLoading
                  ? null
                  : () {
                      if (_thumbnailBytes != null) {
                        _openVideoPlayer();
                      } else {
                        widget.videoMessageConfig?.onTap != null
                            ? widget.videoMessageConfig?.onTap!(widget.videoUrl)
                            : null;
                      }
                    },
              child: Transform.scale(
                scale: widget.highlightVideo ? widget.highlightScale : 1.0,
                alignment: widget.isMessageBySender
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  padding: widget.videoMessageConfig?.padding ?? EdgeInsets.zero,
                  margin: widget.videoMessageConfig?.margin ??
                      EdgeInsets.only(
                        top: 6,
                        right: widget.isMessageBySender ? 6 : 0,
                        left: widget.isMessageBySender ? 0 : 6,
                        bottom: widget.message.reaction.reactions.isNotEmpty ? 15 : 0,
                      ),
                  height: widget.videoMessageConfig?.height ?? 200,
                  width: widget.videoMessageConfig?.width ?? 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black12,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _isThumbnailLoading
                        ? Center(child: CircularProgressIndicator())
                        : _thumbnailBytes != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    _thumbnailBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                  Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white70,
                                      size: 50,
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 50,
                                ),
                              ),
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
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const FullScreenVideoPlayer({Key? key, required this.videoUrl}) : super(key: key);

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
