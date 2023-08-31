import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef VideoOverlayBuilder = Widget Function(
    BuildContext context, AnimationController? controller,
    {bool? autoPlay,
    ValueNotifier<bool>? isPlaying,
    bool? shouldShowPlayPause,
    VoidCallback? play,
    VoidCallback? pause});

class VideoOverlay extends StatefulWidget {
  final VideoOverlayBuilder contentBuilder;
  final bool persistOverlay;
  final Color overlayColor;
  final bool autoPlay;
  final ValueNotifier<bool>? isPlaying;
  final VoidCallback? play;
  final VoidCallback? pause;
  final Future<void>? videoInitialized;
  const VideoOverlay(
    this.contentBuilder, {
    Key? key,
    this.persistOverlay = true,
    this.overlayColor = Colors.black38,
    required this.autoPlay,
    this.play,
    this.pause,
    this.isPlaying,
    this.videoInitialized,
  }) : super(key: key);

  @override
  VideoOverlayState createState() {
    return VideoOverlayState();
  }
}

class VideoOverlayState extends State<VideoOverlay>
    with TickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  VoidCallback? videoPlayerListener;
  VoidCallback? videoProgressListener;
  final Duration _fadeAnimationDuration = const Duration(milliseconds: 300);
  final Duration _timerDuration = const Duration(seconds: 8);
  AnimationController? _fadeController;
  Timer? _timer;
  bool _isHolding = false;
  RouteObserver<ModalRoute>? _observer;
  late PageRoute _myRoute;
  bool _shouldShowPlayPause = false;

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureFadeAnimation();
  }

  @override
  didChangeDependencies() {
    _observer = Provider.of<RouteObserver<ModalRoute>>(context);
    ModalRoute? route = ModalRoute.of(context);
    if (route != null) {
      _myRoute = route as PageRoute<dynamic>;
      _observer?.unsubscribe(this);
      _observer?.subscribe(this, _myRoute);
    }
    super.didChangeDependencies();
  }

  @override
  void didPushNext() {
    _cancelTimer();
  }

  @override
  void didPopNext() {
    if (widget.autoPlay) {
      showOverlay(false);
    }
  }

  void _configureFadeAnimation() {
    _fadeController =
        AnimationController(vsync: this, duration: _fadeAnimationDuration);
    _fadeController!.value = 1.0;
    _fadeController!.addStatusListener(_handleFadeStatus);
    if (widget.autoPlay) {
      _fadeController!.value = 0.0;
      _configureTimer();
    }
  }

  @override
  dispose() {
    _observer?.unsubscribe(this);
    _fadeController?.removeStatusListener(_handleFadeStatus);
    _fadeController?.dispose();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  showOverlay(bool isHolding) async {
    // if (!widget.videoInitialized.value) {
    //   return;
    // }
    await widget.videoInitialized;
    _cancelTimer();
    _isHolding = isHolding;
    if (_fadeController!.isCompleted) {
      _configureTimer();
    } else if (_fadeController!.isDismissed) {
      _fadeController!.forward();
    }
  }

  hideOverlay(_) async {
    // if (!widget.videoInitialized.value) {
    //   return;
    // }
    await widget.videoInitialized;
    _cancelTimer();
    _isHolding = false;
    if (_fadeController!.isCompleted) {
      _fadeController!.reverse();
    }
  }

  _onTapCancel() {
    _isHolding = false;
  }

  void _cancelTimer() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }
  }

  void _configureTimer() {
    _cancelTimer();
    _timer = Timer(_timerDuration, () {
      if (!mounted) return;
      if (_fadeController!.isCompleted) {
        _fadeController!.reverse();
      }
    });
  }

  _handleFadeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_isHolding) {
      _configureTimer();
    } else if (status == AnimationStatus.dismissed) {
      if (!_shouldShowPlayPause) {
        setState(() {
          _shouldShowPlayPause = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.persistOverlay) {
      return Provider.value(
        value: this,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTapUp: hideOverlay,
            onTapDown: (_) => showOverlay(true),
            onTapCancel: _onTapCancel,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                FadeTransition(
                  opacity: _fadeController!,
                  child: Container(
                    color: widget.overlayColor,
                  ),
                ),
                widget.contentBuilder(context, _fadeController,
                    autoPlay: widget.autoPlay,
                    shouldShowPlayPause: _shouldShowPlayPause,
                    isPlaying: widget.isPlaying,
                    pause: widget.pause,
                    play: widget.play),
              ],
            ),
          ),
        ),
      );
    }
    return ElevatedButton(
      onPressed: () => showOverlay(true),
      child: widget.contentBuilder(context, _fadeController,
          autoPlay: widget.autoPlay,
          shouldShowPlayPause: _shouldShowPlayPause,
          isPlaying: widget.isPlaying,
          pause: widget.pause,
          play: widget.play),
    );
  }
}
