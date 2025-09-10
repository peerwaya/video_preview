import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoPlayerFocus extends StatefulWidget {
  final VideoPlayerController videoController;
  final Widget child;
  const VideoPlayerFocus(this.videoController, this.child, {Key? key})
      : super(key: key);

  @override
  _VideoPlayerFocusState createState() {
    return _VideoPlayerFocusState();
  }
}

class _VideoPlayerFocusState extends State<VideoPlayerFocus>
    with RouteAware, WidgetsBindingObserver {
  RouteObserver<ModalRoute>? _observer;
  ModalRoute? _myRoute;
  bool _wasPlayingBeforePause = false;
  bool _isVisible = false;

  bool get canPlay =>
      (_myRoute?.isCurrent ?? false) &&
      (_myRoute?.isActive ?? false) &&
      _isVisible;

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _wasPlayingBeforePause = widget.videoController.value.isPlaying;
        if (!mounted) return;
        widget.videoController.pause();
        break;
      case AppLifecycleState.resumed:
        if (!mounted) return;
        if (_wasPlayingBeforePause && canPlay) {
          widget.videoController.play();
        }
        break;
      default:
    }
  }

  @override
  didChangeDependencies() {
    _observer = Provider.of<RouteObserver<ModalRoute>>(context);
    ModalRoute? route = ModalRoute.of(context);
    if (route != null) {
      _myRoute = route;
      _observer?.unsubscribe(this);
      _observer?.subscribe(this, _myRoute!);
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    _wasPlayingBeforePause = widget.videoController.value.isPlaying;
    widget.videoController.pause();
  }

  @override
  void didPopNext() {
    if (_wasPlayingBeforePause && canPlay) {
      widget.videoController.play();
    }
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
        key: widget.key!,
        onVisibilityChanged: (visibilityInfo) {
          if (!mounted) {
            return;
          }
          // print("visibilityInfo: ${visibilityInfo.visibleFraction}");
          _isVisible = visibilityInfo.visibleFraction >= 100;
          if (_isVisible && _wasPlayingBeforePause && canPlay) {
            widget.videoController.play();
          }

          if (visibilityInfo.visibleFraction <= 0) {
            _wasPlayingBeforePause = widget.videoController.value.isPlaying;
            widget.videoController.pause();
          }
          // if (_isVisible) {
          //   if (_wasPlayingBeforePause && canPlay) {
          //     widget.videoController?.play();
          //   }
          // } else {
          //   _wasPlayingBeforePause =
          //       widget.videoController?.value?.isPlaying ?? false;
          //   widget.videoController.pause();
          // }
        },
        child: widget.child,
      );
}
