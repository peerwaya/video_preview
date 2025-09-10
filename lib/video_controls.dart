import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:video_preview/dots_loader.dart';

const _shadow = <Shadow>[
  Shadow(
    offset: Offset(2.0, 8.0),
    blurRadius: 8.0,
    color: Color.fromRGBO(0, 0, 0, 0.3),
  )
];

class VideoControls extends StatefulWidget {
  final ValueNotifier<bool>? isPlaying;
  final ValueNotifier<bool>? isBuffering;
  final ValueNotifier<bool>? isMuted;
  final VoidCallback? play;
  final VoidCallback? pause;
  final VoidCallback? mute;
  final VoidCallback? unMute;
  final Future<void>? videoInitialized;
  final VoidCallback? onFullscreen;

  const VideoControls(
      {Key? key,
      this.play,
      this.pause,
      this.isPlaying,
      this.isBuffering,
      this.isMuted,
      this.mute,
      this.unMute,
      this.videoInitialized,
      this.onFullscreen})
      : super(key: key);

  @override
  VideoControlstate createState() {
    return VideoControlstate();
  }
}

class VideoControlstate extends State<VideoControls>
    with TickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  VoidCallback? videoPlayerListener;
  VoidCallback? videoProgressListener;

  void _play() async {
    if (widget.videoInitialized != null) {
      await widget.videoInitialized;
      widget.play?.call();
    } else {
      widget.play?.call();
    }
  }

  void _pause() {
    widget.pause?.call();
  }

  void _togglePlayPause() {
    if (widget.isPlaying!.value) {
      _pause();
    } else {
      _play();
    }
  }

  void _toggleMute() {
    if (widget.isMuted!.value) {
      widget.unMute?.call();
    } else {
      widget.mute?.call();
    }
  }

  Widget _buildPlayButton() {
    return Container(
      width: 72.0,
      height: 72.0,
      decoration:
          const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      child: Center(
        child: Icon(
          MdiIcons.play,
          color: Colors.white,
          shadows: _shadow,
          size: 48.0,
        ),
      ),
    );
  }

  Widget _buildPlay() {
    return FutureBuilder(
      future: widget.videoInitialized,
      builder: (BuildContext context, snapshot) {
        Widget body;
        if (snapshot.connectionState == ConnectionState.done) {
          body = _buildPlayButton();
        } else {
          body = const Center(
            child: DotsLoader(
              color: Colors.white54,
              size: 24.0,
            ),
          );
        }
        return AnimatedSwitcher(
            duration: kThemeAnimationDuration,
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: body);
      },
    );
  }

  Widget _buildBuffering() {
    return ValueListenableBuilder(
      builder: (context, dynamic isBuffering, child) {
        return AnimatedSwitcher(
          duration: kThemeAnimationDuration,
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: isBuffering ? child : const SizedBox.shrink(),
        );
      },
      child: const Center(
        child: DotsLoader(
          color: Colors.white54,
          size: 24.0,
        ),
      ),
      valueListenable: widget.isBuffering!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: this,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
            onTap: _togglePlayPause,
            behavior: HitTestBehavior.translucent,
            child: Stack(
              children: [
                Center(
                  child: ValueListenableBuilder(
                    builder: (context, dynamic isPlaying, play) {
                      return AnimatedSwitcher(
                        duration: kThemeAnimationDuration,
                        switchInCurve: Curves.easeIn,
                        switchOutCurve: Curves.easeOut,
                        child: isPlaying
                            ? widget.isBuffering != null
                                ? _buildBuffering()
                                : const SizedBox.shrink()
                            : play,
                      );
                    },
                    child: _buildPlay(),
                    valueListenable: widget.isPlaying!,
                  ),
                ),
                if (widget.isMuted != null)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder(
                          builder: (context, bool isMuted, play) {
                            return SizedBox(
                              // width: 24,
                              // height: 24,
                              child: IconButton(
                                onPressed: _toggleMute,
                                //padding: const EdgeInsets.all(0),
                                icon: isMuted
                                    ? const Icon(
                                        Icons.volume_off,
                                        color: Colors.white,
                                        shadows: _shadow,
                                        size: 20,
                                      )
                                    : const Icon(
                                        Icons.volume_up,
                                        color: Colors.white,
                                        shadows: _shadow,
                                        size: 20,
                                      ),
                              ),
                            );
                          },
                          child: _buildPlay(),
                          valueListenable: widget.isMuted!,
                        ),
                        if (widget.onFullscreen != null)
                          IconButton(
                            onPressed: widget.onFullscreen,
                            icon: const Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                              shadows: _shadow,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  )
              ],
            )),
      ),
    );
  }
}
