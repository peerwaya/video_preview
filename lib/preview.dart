import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:blurhash/blurhash.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:video_player/video_player.dart';
import 'interface.dart';
import 'video_player_focus.dart';

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
  final Duration? invalidateCacheIfOlderThan;
  final bool isMuted;
  final bool showProgressIndicator;

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
    this.invalidateCacheIfOlderThan,
    this.isMuted = false,
    this.showProgressIndicator = false,
  }) : super(key: key);

  @override
  VideoPreviewState createState() {
    return VideoPreviewState();
  }
}

class VideoPreviewState extends State<VideoPreview>
    with TickerProviderStateMixin {
  late CachedVideoPlayerPlus _videoPlayer;
  VoidCallback? videoPlayerListener;
  VoidCallback? videoProgressListener;
  Future<void>? _initializeVideoPlayerFuture;
  StreamSubscription? _eventSub;
  double _volume = 0.0;
  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isBuffering = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _videoLoaded = ValueNotifier<bool>(false);

  @override
  initState() {
    super.initState();
    switch (widget.dataSourceType) {
      case DataSourceType.network:
        _videoPlayer = CachedVideoPlayerPlus.networkUrl(
          Uri.parse(widget.videoUrl),
          invalidateCacheIfOlderThan:
              widget.invalidateCacheIfOlderThan ?? const Duration(days: 30),
        );
        break;
      case DataSourceType.file:
        _videoPlayer = CachedVideoPlayerPlus.file(
          File(widget.videoUrl),
        );
        break;
      case DataSourceType.asset:
        _videoPlayer = CachedVideoPlayerPlus.asset(
          widget.videoUrl,
        );
        break;
      case DataSourceType.contentUri:
        _videoPlayer = CachedVideoPlayerPlus.contentUri(
          Uri.parse(widget.videoUrl),
        );
        break;
    }
    _initVideo();
  }

  _initVideo() async {
    _initializeVideoPlayerFuture = _videoPlayer.initialize();
    await _initializeVideoPlayerFuture;
    if ((kIsWeb && widget.autoPlay) || widget.isMuted) {
      _volume = _videoPlayer.controller.value.volume;
      await _videoPlayer.controller.setVolume(0.0);
      _isMuted.value = true;
    } else {
      _isMuted.value = _videoPlayer.controller.value.volume == 0.0;
      _volume = _videoPlayer.controller.value.volume;
    }
    _videoPlayer.controller.setLooping(true);
    if (widget.autoPlay) {
      _videoPlayer.controller.play();
    }
    _videoLoaded.value = true;
    _videoPlayer.controller.addListener(_checkIsPlaying);
    widget.onPlayerControllerCreated?.call(_videoPlayer.controller);
    if (mounted) {
      setState(() {});
    }
  }

  void _checkIsPlaying() {
    _isPlaying.value = _videoPlayer.controller.value.isPlaying;
    _isBuffering.value = _videoPlayer.controller.value.isBuffering;
    _isMuted.value = _videoPlayer.controller.value.volume == 0.0;
  }

  @override
  dispose() {
    _videoPlayer.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  _pauseVideo() async {
    if (!_videoPlayer.controller.value.isInitialized) {
      return;
    }
    await _videoPlayer.controller.pause();
  }

  _mute() async {
    if (!_videoPlayer.controller.value.isInitialized) {
      return;
    }
    _volume = _videoPlayer.controller.value.volume;
    await _videoPlayer.controller.setVolume(0.0);
  }

  _unMute() async {
    if (!_videoPlayer.controller.value.isInitialized) {
      return;
    }
    await _videoPlayer.controller.setVolume(_volume);
  }

  _playVideo() async {
    if (!_videoPlayer.controller.value.isInitialized) {
      return;
    }
    if (_videoPlayer.controller.value.position >=
        _videoPlayer.controller.value.duration) {
      _videoPlayer.controller.seekTo(const Duration(seconds: 0));
    }
    await _videoPlayer.controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return _videoPlayer.isInitialized
        ? ValueListenableBuilder(
            valueListenable: _videoPlayer.controller,
            builder: (context, value, child) {
              if (!value.isInitialized && widget.videoImageUrl != null) {
                return widget.radius != null
                    ? ClipRRect(
                        borderRadius: widget.radius!,
                        child: Image(
                          image:
                              CachedNetworkImageProvider(widget.videoImageUrl!),
                          fit: widget.boxFit,
                        ),
                      )
                    : Image(
                        image:
                            CachedNetworkImageProvider(widget.videoImageUrl!),
                        fit: widget.boxFit,
                      );
              }
              final width =
                  widget.width ?? (value.isInitialized ? value.size.width : 0);
              final height = widget.height ??
                  (value.isInitialized ? value.size.height : 0);
              final aspectRatio = height == 0 ? 0 : width / height;
              if (aspectRatio <= 0) {
                return const SizedBox.shrink();
              }
              final videoContent = Container(
                decoration: BoxDecoration(
                  boxShadow: widget.shadow,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: widget.boxFit,
                      //aspectRatio: aspectRatio.toDouble(),
                      child: SizedBox(
                        width: width.toDouble(),
                        height: height.toDouble(),
                        child: VideoPlayerFocus(
                          _videoPlayer.controller,
                          widget.radius != null
                              ? ClipRRect(
                                  borderRadius: widget.radius!,
                                  child: VideoPlayer(
                                    _videoPlayer.controller,
                                  ),
                                )
                              : VideoPlayer(
                                  _videoPlayer.controller,
                                ),
                          key: ValueKey(widget.videoUrl),
                        ),
                      ),
                    ),
                    PointerInterceptor(
                      child: SizedBox.expand(
                        child: widget.contentBuilder != null
                            ? widget.contentBuilder!(
                                context,
                                _videoPlayer.controller,
                                play: _playVideo,
                                pause: _pauseVideo,
                                isMuted: _isMuted,
                                mute: _mute,
                                unMute: _unMute,
                                isPlaying: _isPlaying,
                                isBuffering: _isBuffering,
                                autoPlay: widget.autoPlay,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              );
              return videoContent;
            },
          )
        : const SizedBox.shrink();
  }
}
