import 'dart:math' as math;
import 'package:flutter/widgets.dart';

class _DelayTween extends Tween<double> {
  final double? delay;

  _DelayTween({
    double? begin,
    double? end,
    this.delay,
  }) : super(begin: begin, end: end);

  @override
  double lerp(double t) {
    return super.lerp((math.sin((t - delay!) * 2 * math.pi) + 1) / 2);
  }

  @override
  double evaluate(Animation<double> animation) => lerp(animation.value);
}

class DotsLoader extends StatefulWidget {
  final Color? color;
  final double size;
  final IndexedWidgetBuilder? itemBuilder;

  const DotsLoader({
    Key? key,
    this.color,
    this.size = 50.0,
    this.itemBuilder,
  })  : assert(
            !(itemBuilder is IndexedWidgetBuilder && color is Color) &&
                !(itemBuilder == null && color == null),
            'You should specify either a itemBuilder or a color'),
        super(key: key);

  @override
  _EllipsisLoaderState createState() => _EllipsisLoaderState();
}

class _EllipsisLoaderState extends State<DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  final _duration = const Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: _duration,
    )..repeat();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.fromSize(
        size: Size(widget.size * 2, widget.size),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _circle(0, .0),
            _circle(1, .2),
            _circle(2, .4),
          ],
        ),
      ),
    );
  }

  Widget _circle(int index, double delay) {
    final _size = widget.size * 0.5;
    return ScaleTransition(
      scale:
          _DelayTween(begin: 0.0, end: 1.0, delay: delay).animate(_scaleCtrl),
      child: SizedBox.fromSize(
        size: Size.square(_size),
        child: _itemBuilder(index),
      ),
    );
  }

  Widget _itemBuilder(int index) {
    return widget.itemBuilder != null
        ? widget.itemBuilder!(context, index)
        : DecoratedBox(
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          );
  }
}
