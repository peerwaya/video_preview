import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:browser_adapter/browser_adapter.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:video_player/video_player.dart';
import 'interface.dart';
import 'video_player_focus.dart';

class ImageBackdrop extends StatefulWidget {
  final BoxFit boxFit;
  final String? imageUrl;
  const ImageBackdrop(this.imageUrl, {this.boxFit = BoxFit.cover, Key? key})
      : super(key: key);

  @override
  _ImageBackdropState createState() => _ImageBackdropState();
}

class _ImageBackdropState extends State<ImageBackdrop> {
  late Widget filter;
  late ImageProvider provider;
  Widget? coveredImage;
  @override
  void initState() {
    provider = CachedNetworkImageProvider(widget.imageUrl!);
    coveredImage = Image(
      image: CachedNetworkImageProvider(widget.imageUrl!),
      fit: BoxFit.cover,
    );
    filter = ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Opacity(
          opacity: 0.4,
          child: Transform.scale(
            scale: 3,
            child: Image(
              image: CachedNetworkImageProvider(widget.imageUrl!),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl == null) return const SizedBox.expand();
    if (widget.boxFit == BoxFit.cover) {
      return Container(color: Colors.black, child: coveredImage);
    }
    if (isSafariBrowser()) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.4,
              child: Transform.scale(
                scale: 3,
                child: Image(
                  image: CachedNetworkImageProvider(widget.imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Image(
                  image: provider,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        filter,
        Image(
          image: provider,
          fit: BoxFit.contain,
        )
      ]),
    );
  }
}

typedef OnVideoPlayerControllerCreated = void Function(
    VideoPlayerController? controller);

class VideoPreview extends StatefulWidget {
  final VideoContentBuilder? contentBuilder;
  final String videoUrl;
  final String? videoImageUrl;
  final bool autoPlay;
  final VoidCallback? onClose;
  final DataSourceType dataSourceType;
  final BoxFit boxFit;
  final int? width;
  final int? height;
  final String? backgroundImageUrl;
  final OnVideoPlayerControllerCreated? onPlayerControllerCreated;
  final bool observeRoute;
  const VideoPreview(
    this.videoUrl, {
    this.width,
    this.height,
    Key? key,
    this.contentBuilder,
    this.videoImageUrl,
    this.autoPlay = true,
    this.onClose,
    this.boxFit = BoxFit.cover,
    this.dataSourceType = DataSourceType.network,
    this.backgroundImageUrl,
    this.onPlayerControllerCreated,
    this.observeRoute = true,
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
        _videoController = VideoPlayerController.network(
          widget.videoUrl,
          videoPlayerOptions:
              VideoPlayerOptions(enableObserver: false, cacheEnabled: true),
        );
        break;
      case DataSourceType.file:
        _videoController = VideoPlayerController.file(
          File(widget.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(enableObserver: false),
        );
        break;
      case DataSourceType.asset:
        _videoController = VideoPlayerController.asset(
          widget.videoUrl,
          videoPlayerOptions: VideoPlayerOptions(enableObserver: false),
        );
        break;
    }
    _videoController.addListener(_checkIsPlaying);
    _initVideo();
  }

  _initVideo() async {
    await _videoController.setVolume(0);
    await _videoController.setMuted(true);
    _initializeVideoPlayerFuture = _videoController.initialize();
    await _initializeVideoPlayerFuture;
    _videoController.setLooping(true);
    if (widget.autoPlay) {
      _videoController.play();
    }
    _videoLoaded.value = true;
    widget.onPlayerControllerCreated?.call(_videoController);
    setState(() {});
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
          child: VideoPlayerFocus(
            _videoController,
            VideoPlayer(_videoController),
            key: ValueKey(widget.videoUrl),
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
          child: VideoPlayerFocus(
            _videoController,
            VideoPlayer(
              _videoController,
            ),
            key: ValueKey(widget.videoUrl),
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
        ImageBackdrop(
          widget.videoImageUrl,
          key: ValueKey(widget.videoImageUrl),
          boxFit: widget.boxFit,
        ),
        ValueListenableBuilder(
          valueListenable: _videoLoaded,
          builder: (BuildContext context, bool value, Widget? image) {
            return _buildVideo();
          },
        ),
        PointerInterceptor(
          child: SizedBox.expand(
            child: widget.contentBuilder!(context,
                play: _playVideo,
                pause: _pauseVideo,
                isPlaying: _isPlaying,
                isBuffering: _isBuffering,
                autoPlay: widget.autoPlay,
                videoInitialized: _initializeVideoPlayerFuture),
          ),
        ),
      ],
    );
  }
}