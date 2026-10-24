import 'package:flutter/material.dart';

abstract final class AppColors {
  static const paper = Color(0xFFFFFBF4);
  static const surface = Color(0xFFFFFFFF);

  /// Translucent white for resting pills that sit on the page gradient.
  static const surfaceSoft = Color(0x99FFFFFF);
  static const ink = Color(0xFF34408F);
  static const seal = ink;
  static const sealDeep = Color(0xFF232B66);
  static const wash = Color(0xFF8A90B8);
  static const muted = Color(0xFF5B6089);
  static const dockSelection = Color(0xFF4F5BA8);
  static const error = Color(0xFFBB3049);
  static const hairline = Color(0xFFE6E4F0);

  /// Wash at 40%, for connector lines that must stay visible on the page
  /// gradient where [hairline] disappears.
  static const rail = Color(0x668A90B8);
  static const washTint = Color(0xFFF5F2FA);
  static const sealTint = Color(0xFFFFE8B5);
  static const sealSelection = Color(0xFFE4DAF4);
  static const sunshine = Color(0xFFFFC95C);
  static const teal = Color(0xFF4FB8A4);
  static const blossom = Color(0xFFF28BA8);
  static const childButter = Color(0xFFFFEDBA);
  static const childMint = Color(0xFFDDF2E9);
  static const childRose = Color(0xFFFBE2E9);
  static const orchid = Color(0xFFA98BD6);
  static const lilac = Color(0xFFEFE6F8);
  static const peach = Color(0xFFFFE3C4);
  static const purple = Color(0xFF6844D5);
  static const shadow = Color(0x1434408F);
  static const onDarkMuted = Color(0xFFD3D6EE);
  static const pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0, 0.12, 0.42, 1],
    colors: [peach, lilac, paper, paper],
  );
  static const darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A57AE), ink, sealDeep],
  );
}
