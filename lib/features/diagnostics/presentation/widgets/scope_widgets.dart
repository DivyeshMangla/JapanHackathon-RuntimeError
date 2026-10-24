import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/diagnostic_colors.dart';

/// Bordered black panel with a channel-style header, like an instrument
/// readout.
class ScopePanel extends StatelessWidget {
  const ScopePanel({
    super.key,
    required this.title,
    required this.child,
    this.status,
  });

  final String title;
  final Widget child;

  /// Short state shown at the right of the header, such as "LIVE".
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DiagnosticColors.panel,
        border: Border.all(color: DiagnosticColors.border),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTypography.monoSmall.copyWith(
                      color: DiagnosticColors.trace,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                ?status,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

/// A labelled numeric readout. [alert] turns the value red; the caption
/// always says why in words.
class ScopeReadout extends StatelessWidget {
  const ScopeReadout({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.alert = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.monoMicro.copyWith(
            color: DiagnosticColors.textDim,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          value,
          style: AppTypography.monoHeadline.copyWith(
            color: alert ? DiagnosticColors.alert : DiagnosticColors.trace,
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            style: AppTypography.monoMicro.copyWith(
              color: alert ? DiagnosticColors.alert : DiagnosticColors.textDim,
            ),
          ),
      ],
    );
  }
}

/// Lays readouts out in a two-column grid that wraps on narrow screens.
class ReadoutGrid extends StatelessWidget {
  const ReadoutGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// A status word with a coloured marker; the word carries the meaning.
class ScopeStatus extends StatelessWidget {
  const ScopeStatus({super.key, required this.text, this.alert = false});

  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = alert ? DiagnosticColors.alert : DiagnosticColors.trace;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: AppSpacing.sm),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text.toUpperCase(),
          style: AppTypography.monoMicro.copyWith(
            color: color,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
