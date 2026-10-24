import 'package:flutter/animation.dart';

/// Spacing scale (4/8/16/24/32), built on design.md's 8px base unit.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// design.md's 1.5rem page side padding.
  static const double gutter = lg;
  static const double maxContentWidth = 1280;
}

/// Soft cards, compact surfaces and capsule controls.
abstract final class AppRadius {
  static const double small = 16;
  static const double base = 28;
  static const double pill = 100;
}

abstract final class AppSizes {
  /// Minimum touch target from the accessibility guidelines.
  static const double minTouchTarget = 48;

  /// Fixed column for short values (percentages, codes) so rows align.
  static const double valueColumn = 56;

  /// Fixed column for step numbers and small counters.
  static const double counterColumn = 32;

  /// Fits a 360px-wide phone inside the gutter and the white quiet zone.
  static const double qrCode = 280;
  static const double signaturePad = 180;
  static const double signaturePreview = 120;

  /// Reading width for step-by-step forms and consent text on tablets.
  static const double readingWidth = 560;

  /// The Melo mark at the top of the welcome page.
  static const double welcomeMark = 88;

  /// Coloured circle behind the icon of a welcome choice.
  static const double choiceIcon = 56;

  /// The child's picture tiles: tall enough for a big icon and a word, and
  /// an easy target for small fingers.
  static const double childTile = 152;
  static const double childTileIcon = 72;

  /// The mascot on the child's home page and in celebrations.
  static const double childMascot = 96;

  /// Width of the full logo on launch. Android 12+ masks its splash icon to a
  /// 192dp circle, and the logo fits that circle at this width; the native
  /// splashes use the same width so the hand-over to Flutter does not jump.
  /// Keep in step with LAUNCH_WIDTH in tool/generate_logo.py.
  static const double launchLogo = 168;
}

/// Motion tokens from design.md: ease-out, 200-300ms, 420ms entries.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 200);
  static const standard = Duration(milliseconds: 300);
  static const entry = Duration(milliseconds: 420);
  static const stagger = Duration(milliseconds: 80);
  static const curve = Curves.easeOut;
  static const entryOffset = 16.0;
}
