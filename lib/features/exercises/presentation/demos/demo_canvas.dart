import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The shared drawing space for every exercise illustration: a fixed
/// 200 x 150 design space, so poses and props are authored once in the same
/// units whatever the screen size. Each exercise frames the part of the
/// space its scene uses, which is scaled to fit and centred.
class DemoCanvas {
  factory DemoCanvas(Size size, {Rect frame = full}) {
    final scale = math.min(
      size.width / frame.width,
      size.height / frame.height,
    );
    final centre = Offset(size.width / 2, size.height / 2);
    return DemoCanvas._(scale, centre - frame.center * scale);
  }

  const DemoCanvas._(this.scale, this.origin);

  static const width = 200.0;
  static const height = 150.0;
  static const full = Rect.fromLTWH(0, 0, width, height);

  final double scale;
  final Offset origin;

  /// Maps the canvas into design space.
  void apply(Canvas canvas) {
    canvas
      ..translate(origin.dx, origin.dy)
      ..scale(scale);
  }
}
