import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';
import 'diagnostic_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.seal,
      onPrimary: AppColors.paper,
      secondary: AppColors.ink,
      onSecondary: AppColors.paper,
      tertiary: AppColors.wash,
      onTertiary: AppColors.paper,
      error: AppColors.error,
      onError: AppColors.paper,
      surface: AppColors.paper,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      surfaceContainerLowest: AppColors.paper,
      surfaceContainerLow: AppColors.paper,
      surfaceContainer: AppColors.paper,
      surfaceContainerHigh: AppColors.paper,
      surfaceContainerHighest: AppColors.paper,
      outline: AppColors.wash,
      outlineVariant: AppColors.hairline,
      shadow: AppColors.ink,
      inverseSurface: AppColors.ink,
      onInverseSurface: AppColors.paper,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.base),
    );
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppFonts.sans,
      fontFamilyFallback: AppFonts.fallback,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadePageTransitionsBuilder(),
          TargetPlatform.iOS: FadePageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.pageTitle,
        toolbarHeight: 72,
        titleSpacing: AppSpacing.lg,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: const WidgetStatePropertyAll(AppTypography.button),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.wash
                : AppColors.paper,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.washTint;
            }
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered)) {
              return AppColors.sealDeep;
            }
            return AppColors.seal;
          }),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered) ? 2 : 0,
          ),
          shadowColor: const WidgetStatePropertyAll(AppColors.ink),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          animationDuration: AppMotion.fast,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
          ),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: const WidgetStatePropertyAll(AppTypography.button),
          foregroundColor: const WidgetStatePropertyAll(AppColors.ink),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.hairline),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered)
                ? AppColors.washTint
                : AppColors.surface,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          animationDuration: AppMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.seal,
          textStyle: AppTypography.button,
          shape: shape,
          minimumSize: const Size(48, 48),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          shape: const CircleBorder(),
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: false,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 20,
        ),
        hintStyle: AppTypography.body.copyWith(color: AppColors.muted),
        errorStyle: AppTypography.label.copyWith(color: AppColors.error),
        border: _inputBorder(Colors.transparent, 0),
        enabledBorder: _inputBorder(Colors.transparent, 0),
        focusedBorder: _inputBorder(AppColors.seal, 2),
        errorBorder: _inputBorder(AppColors.error, 1),
        focusedErrorBorder: _inputBorder(AppColors.error, 2),
        disabledBorder: _inputBorder(AppColors.hairline, 1),
        prefixIconColor: AppColors.wash,
        suffixIconColor: AppColors.wash,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.seal,
        selectionColor: AppColors.sealSelection,
        selectionHandleColor: AppColors.seal,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.sealTint,
        indicatorShape: shape,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.seal
                : AppColors.wash,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTypography.label.copyWith(color: AppColors.seal)
              : AppTypography.label.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w400,
                ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: shape,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.sunshine,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: AppTypography.label,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        shape: shape,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: shape,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: shape,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.hairline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.wash, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.seal
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.paper),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.seal,
        linearTrackColor: AppColors.washTint,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTypography.body.copyWith(color: AppColors.paper),
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.base),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.ink,
        textColor: AppColors.ink,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        shape: shape,
      ),
    );
  }

  /// Dark, monospace theme for the developer sensor screen.
  static ThemeData get diagnostics {
    const scheme = ColorScheme.dark(
      primary: DiagnosticColors.trace,
      onPrimary: DiagnosticColors.background,
      secondary: DiagnosticColors.amber,
      error: DiagnosticColors.alert,
      surface: DiagnosticColors.background,
      onSurface: DiagnosticColors.text,
      onSurfaceVariant: DiagnosticColors.textDim,
      outline: DiagnosticColors.border,
    );
    final text = AppTypography.textTheme
        .apply(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          bodyColor: DiagnosticColors.text,
          displayColor: DiagnosticColors.text,
        )
        .copyWith(
          bodySmall: AppTypography.monoSmall.copyWith(
            color: DiagnosticColors.textDim,
          ),
        );
    return light.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: DiagnosticColors.background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: DiagnosticColors.background,
        foregroundColor: DiagnosticColors.trace,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.monoLarge.copyWith(
          color: DiagnosticColors.trace,
          letterSpacing: 2,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DiagnosticColors.trace,
          textStyle: AppTypography.monoSmall,
          minimumSize: const Size(
            AppSizes.minTouchTarget,
            AppSizes.minTouchTarget,
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.base),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// design.md: page transitions are a 200ms fade only.
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.fast;

  @override
  Duration get reverseTransitionDuration => AppMotion.fast;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: AppMotion.curve),
      child: child,
    );
  }
}
