import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppFonts {
  static const sans = 'NunitoSans';
  static const mono = 'JetBrainsMono';

  /// Scripts the bundled Latin fonts lack, ready for Hindi and Punjabi
  /// translations.
  static const fallback = ['NotoSansDevanagari', 'NotoSansGurmukhi'];
}

/// Type scale from design.md mapped onto Material text roles.
abstract final class AppTypography {
  static const hero = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.8,
    height: 1.15,
    color: AppColors.ink,
  );

  static const h1 = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.6,
    height: 1.2,
    color: AppColors.ink,
  );

  static const h2 = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    height: 1.3,
    color: AppColors.ink,
  );

  static const h3 = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.ink,
  );

  static const label = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.ink,
  );

  static const button = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  static const mono = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.ink,
  );

  /// Small labels such as chips and status flags.
  static const caption = TextStyle(
    fontFamily: AppFonts.sans,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.ink,
  );

  /// Metadata such as timestamps and durations.
  static final monoSmall = mono.copyWith(fontSize: 12);

  /// Chart axis labels, where space is tight.
  static final monoMicro = mono.copyWith(fontSize: 10);

  /// Prominent technical values such as reminder times and counts.
  static final monoLarge = mono.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  /// The recording timer.
  static final monoDisplay = mono.copyWith(
    fontSize: 44,
    fontWeight: FontWeight.w500,
  );

  /// Live sensor readouts such as angles.
  static final monoHeadline = mono.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w500,
  );

  /// Participant codes such as P001.
  static final participantCode = monoSmall.copyWith(
    fontWeight: FontWeight.w500,
    color: AppColors.seal,
  );

  static final recordTimer = monoDisplay.copyWith(
    fontSize: 56,
    letterSpacing: -1.5,
  );

  static final pageTitle = h1.copyWith(fontSize: 28);

  static TextTheme get textTheme => TextTheme(
    displayLarge: hero,
    displayMedium: hero,
    displaySmall: h1,
    headlineLarge: h1,
    headlineMedium: h2,
    headlineSmall: h3,
    titleLarge: h3,
    titleMedium: body.copyWith(fontWeight: FontWeight.w500, height: 1.35),
    titleSmall: label.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: label.copyWith(
      fontWeight: FontWeight.w400,
      color: AppColors.muted,
    ),
    labelLarge: button,
    labelMedium: label,
    labelSmall: label.copyWith(fontSize: 12),
  );
}
