import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'melo_mark.dart';

/// Circular badge used for feature shortcuts and the app identity. Without an
/// [icon] it shows the Melo mark on a white disc.
class SealMark extends StatelessWidget {
  const SealMark({super.key, this.size = 56, this.icon});
  final double size;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final glyph = icon;
    if (glyph == null) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
        ),
        alignment: Alignment.center,
        child: MeloMark(size: size * 0.78),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.darkGradient,
      ),
      child: Icon(glyph, size: size * 0.46, color: AppColors.surface),
    );
  }
}
