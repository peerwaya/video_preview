import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:blurhash/blurhash.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';
import 'interface.dart';
import 'video_player_focus.dart';

const _kDuration = Duration(milliseconds: 600);

class ImageBackdrop extends StatefulWidget {
  final BoxFit boxFit;
  final String? imageUrl;
  final String blurHash;
  final Color blurColor;
  final List<BoxShadow>? shadow;

  const ImageBackdrop(this.imageUrl,
      {this.boxFit = BoxFit.cover,
      required this.blurHash,
      this.blurColor = Colors.black,
      this.shadow,
      Key? key})
      : super(key: key);

  @override
  State<ImageBackdrop> createState() => _ImageBackdropState();
}

class _ImageBackdropState extends State<ImageBackdrop> {
  Uint8List? _imageDataBytes;
  @override
  void initState() {
    super.initState();
    blurHashDecode();
  }

  Future blurHashDecode() async {
    Uint8List? imageDataBytes;
    try {
      imageDataBytes = await BlurHash.decode(widget.blurHash, 32, 32);
    } on PlatformException catch (e) {
      throw Exception(e.message);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _imageDataBytes = imageDataBytes;
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    return widget.imageUrl != null
        ? Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (_imageDataBytes != null)
                Image.memory(
                  _imageDataBytes!,
                  fit: BoxFit.cover,
                ),
              if (widget.imageUrl != null)
                Container(
                  decoration: BoxDecoration(boxShadow: widget.shadow),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl!,
                    fit: widget.boxFit,
                  ),
                ),
            ],
          )
        : _imageDataBytes != null
            ? Container(
                decoration: BoxDecoration(boxShadow: widget.shadow),
                child: Image.memory(
                  _imageDataBytes!,
                  fit: BoxFit.cover,
                ),
              )
            : const SizedBox.shrink();
  }
}

typedef OnVideoPlayerControllerCreated = void Function(
    VideoPlayerController? controller);

class VideoPreview extends StatefulWidget {
  final VideoContentBuilder? contentBuilder;
  final String videoUrl;
  final String? videoImageUrl;
  final String? blurHash;
  final bool autoPlay;
  final VoidCallback? onClose;
  final DataSourceType dataSourceType;
  final BoxFit boxFit;
  final int? width;
  final int? height;
  final String? backgroundImageUrl;
  final OnVideoPlayerControllerCreated? onPlayerControllerCreated;
  final bool observeRoute;
  final BorderRadius? radius;
  final Color blurColor;
  final bool backdropEnabled;
  final List<BoxShadow>? shadow;
  const VideoPreview(
    this.videoUrl, {
    this.width,
    this.height,
    Key? key,
    this.contentBuilder,
    this.videoImageUrl,
    this.blurHash,
    this.autoPlay = true,
    this.onClose,
    this.boxFit = BoxFit.cover,
    this.dataSourceType = DataSourceType.network,
    this.backgroundImageUrl,
    this.onPlayerControllerCreated,
    this.observeRoute = true,
    this.blurColor = Colors.black,
    this.backdropEnabled = true,
    this.radius,
    this.shadow,
  }) : super(key: key);

  @override
  VideoPreviewState createState() {
    return VideoPreviewState();
  }
}

class VideoPreviewState extends State<VideoPreview>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  VoidCallback? videoPlayerListener;
  VoidCallback? videoProgressListener;
  Future<void>? _initializeVideoPlayerFuture;
  StreamSubscription? _eventSub;
  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _videoLoaded = ValueNotifier<bool>(false);

  @override
  initState() {
    super.initState();
    switch (widget.dataSourceType) {
      case DataSourceType.network:
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
        break;
      case DataSourceType.file:
        _videoController = VideoPlayerController.file(
          File(widget.videoUrl),
        );
        break;
      case DataSourceType.asset:
        _videoController = VideoPlayerController.asset(
          widget.videoUrl,
        );
        break;
      case DataSourceType.contentUri:
        _videoController = VideoPlayerController.contentUri(
          Uri.parse(widget.videoUrl),
        );
        break;
    }
    _videoController.addListener(_checkIsPlaying);
    _initVideo();
  }

  _initVideo() async {
    _initializeVideoPlayerFuture = _videoController.initialize();
    await _initializeVideoPlayerFuture;
    if (kIsWeb && widget.autoPlay) {
      await _videoController.setVolume(0.0);
    }
    _videoController.setLooping(true);
    if (widget.autoPlay) {
      _videoController.play();
    }
    _videoLoaded.value = true;
    widget.onPlayerControllerCreated?.call(_videoController);
    if (mounted) {
      setState(() {});
    }
  }

  void _checkIsPlaying() {
    _isPlaying.value = _videoController.value.isPlaying;
    _isBuffering.value = _videoController.value.isBuffering;
  }

  @override
  dispose() {
    _videoController.removeListener(_checkIsPlaying);
    _videoController.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  _pauseVideo() async {
    if (!_videoController.value.isInitialized) {
      return;
    }
    await _videoController.pause();
  }

  _playVideo() async {
    if (!_videoController.value.isInitialized) {
      return;
    }
    if (_videoController.value.position >= _videoController.value.duration) {
      _videoController.seekTo(const Duration(seconds: 0));
    }
    await _videoController.play();
  }

  Widget _buildVerticalVideo() {
    double width = _videoController.value.size.width;
    double height = _videoController.value.size.height;
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: width,
          height: height,
          child: Container(
            decoration: BoxDecoration(boxShadow: widget.shadow),
            child: VideoPlayerFocus(
              _videoController,
              widget.radius != null
                  ? ClipRRect(
                      borderRadius: widget.radius!,
                      child: VideoPlayer(
                        _videoController,
                      ),
                    )
                  : VideoPlayer(
                      _videoController,
                    ),
              key: ValueKey(widget.videoUrl),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (!_videoController.value.isInitialized) {
      return Container();
    }
    if (widget.boxFit == BoxFit.cover) {
      return _buildVerticalVideo();
    }
    return SizedBox.expand(
      child: Center(
        child: AspectRatio(
          aspectRatio: _videoController.value.aspectRatio,
          child: Container(
            decoration: BoxDecoration(boxShadow: widget.shadow),
            child: VideoPlayerFocus(
              _videoController,
              widget.radius != null
                  ? ClipRRect(
                      borderRadius: widget.radius!,
                      child: VideoPlayer(
                        _videoController,
                      ),
                    )
                  : VideoPlayer(
                      _videoController,
                    ),
              key: ValueKey(widget.videoUrl),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.backdropEnabled && widget.blurHash != null
            ? ImageBackdrop(
                widget.videoImageUrl,
                key: ValueKey(widget.videoImageUrl),
                boxFit: widget.boxFit,
                blurHash: widget.blurHash!,
                blurColor: widget.blurColor,
              )
            : widget.videoImageUrl != null
                ? widget.radius != null
                    ? Center(
                        child: Container(
                          decoration: BoxDecoration(boxShadow: widget.shadow),
                          child: ClipRRect(
                            borderRadius: widget.radius!,
                            child: Image(
                              image: CachedNetworkImageProvider(
                                  widget.videoImageUrl!),
                              fit: widget.boxFit,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Container(
                          decoration: BoxDecoration(boxShadow: widget.shadow),
                          child: Image(
                            image: CachedNetworkImageProvider(
                                widget.videoImageUrl!),
                            fit: widget.boxFit,
                          ),
                        ),
                      )
                : const SizedBox.shrink(),
        ValueListenableBuilder(
          valueListenable: _videoLoaded,
          builder: (BuildContext context, bool value, Widget? image) {
            return _buildVideo();
          },
        ),
        PointerInterceptor(
          child: SizedBox.expand(
            child: widget.contentBuilder != null
                ? widget.contentBuilder!(context,
                    play: _playVideo,
                    pause: _pauseVideo,
                    isPlaying: _isPlaying,
                    isBuffering: _isBuffering,
                    autoPlay: widget.autoPlay,
                    videoInitialized: _initializeVideoPlayerFuture)
                : null,
          ),
        ),
      ],
    );
  }
}
