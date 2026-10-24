import 'package:flutter/painting.dart';

import '../../../../../core/theme/app_colors.dart';

/// Paints for the exercise illustrations: one ink outline weight and flat
/// fills from the app palette, shared by the character and every prop.
/// Widths are in design units.
abstract final class DemoStyle {
  static final outline = Paint()
    ..color = AppColors.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  /// Facial features and laces, a touch finer than outlines.
  static final detail = Paint()
    ..color = AppColors.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;

  static final ink = Paint()..color = AppColors.ink;
  static final skin = Paint()..color = AppColors.surface;
  static final top = Paint()..color = AppColors.sunshine;
  static final trousers = Paint()..color = AppColors.ink;
  static final hair = Paint()..color = AppColors.ink;
  static final shoe = Paint()..color = AppColors.sunshine;
  static final mat = Paint()..color = AppColors.lilac;

  static final stripe = Paint()
    ..color = AppColors.sunshine
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round;

  /// Soft wash behind a scene that sets the figure apart from the card.
  static final backdrop = Paint()
    ..color = AppColors.lilac.withValues(alpha: 0.22);

  static Paint motion(double opacity) => Paint()
    ..color = AppColors.ink.withValues(alpha: opacity.clamp(0, 1))
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;
}
