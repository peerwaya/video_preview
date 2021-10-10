import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_preview/dots_loader.dart';
import 'package:video_preview/video_overlay.dart';
import '../icon_shadow.dart';

const _shadow = <Shadow>[
  Shadow(
    offset: Offset(2.0, 8.0),
    blurRadius: 8.0,
    color: Color.fromRGBO(0, 0, 0, 0.3),
  )
];

typedef VideoContentBuilder = Widget Function(
  BuildContext context, {
  VoidCallback? play,
  VoidCallback? pause,
  ValueNotifier<bool>? isPlaying,
  ValueNotifier<bool>? isBuffering,
  bool? autoPlay,
  Future<void>? videoInitialized,
});

class PlayButton extends StatefulWidget {
  final VoidCallback? onPlay;
  final Future<void>? isInitialized;
  const PlayButton({this.onPlay, this.isInitialized, Key? key})
      : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return PlayButtonState();
  }
}

class PlayButtonState extends State<PlayButton> {
  bool _showLoader = false;

  void play() async {
    if (widget.isInitialized != null) {
      setState(() {
        _showLoader = true;
      });
      await widget.isInitialized;
      widget.onPlay?.call();
      setState(() {
        _showLoader = false;
      });
    } else {
      widget.onPlay?.call();
    }
  }

  Widget _buildPlayButton() {
    return IconButton(
      icon: const IconS(
        Icons.play_arrow_outlined,
        color: Colors.white54,
        shadows: _shadow,
      ),
      iconSize: 72.0,
      onPressed: play,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isInitialized != null
        ? FutureBuilder(
            future: widget.isInitialized,
            builder: (BuildContext context, snapshot) {
              Widget body;
              if (_showLoader) {
                body = const Center(
                  child: DotsLoader(
                    color: Colors.white54,
                    size: 24.0,
                  ),
                );
              } else {
                body = _buildPlayButton();
              }
              return AnimatedSwitcher(
                  duration: kThemeAnimationDuration,
                  switchInCurve: Curves.easeIn,
                  switchOutCurve: Curves.easeOut,
                  child: body);
            },
          )
        : _buildPlayButton();
  }
}

class VideoPlayerControls extends StatelessWidget {
  final bool autoPlay;
  final bool shouldShowPlayPause;
  final VoidCallback? play;
  final VoidCallback? pause;
  final bool isPlaying;
  final Future<void>? videoInitialized;
  const VideoPlayerControls(
      {this.autoPlay = true,
      this.shouldShowPlayPause = false,
      this.isPlaying = false,
      this.play,
      this.pause,
      this.videoInitialized,
      Key? key})
      : super(key: key);

  _handlePlay(BuildContext context) {
    VideoOverlayState state = context.read();
    state.hideOverlay(null);
    play?.call();
  }

  _handlePause(BuildContext context) {
    VideoOverlayState state = context.read();
    state.showOverlay(false);
    pause?.call();
  }

  @override
  Widget build(BuildContext context) {
    if ((autoPlay && !shouldShowPlayPause)) {
      return Container();
    }
    Widget body;
    if (isPlaying) {
      body = IconButton(
        icon: const IconS(
          Icons.pause_circle_filled_outlined,
          color: Colors.white54,
          shadows: _shadow,
        ),
        iconSize: 72.0,
        onPressed: () => _handlePause(context),
      );
    } else {
      body = PlayButton(
        isInitialized: videoInitialized,
        onPlay: () => _handlePlay(context),
      );
      body = IconButton(
        icon: const IconS(
          Icons.play_arrow_outlined,
          color: Colors.white54,
          shadows: _shadow,
        ),
        iconSize: 72.0,
        onPressed: () => _handlePlay(context),
      );
    }
    return SizedBox.expand(
      child: Center(
        child: AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          child: body,
        ),
      ),
    );
  }
}
