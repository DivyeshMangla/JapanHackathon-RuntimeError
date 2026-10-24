import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';

/// A single-select row of pill buttons, wrapping onto new lines as needed.
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.semanticLabelOf,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T>? onSelected;

  /// Spoken label when the visible one is too terse, such as a scale digit.
  final String Function(T option)? semanticLabelOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final option in options)
          _Pill(
            label: labelOf(option),
            semanticLabel: semanticLabelOf?.call(option),
            selected: option == selected,
            onTap: onSelected == null ? null : () => onSelected!(option),
          ),
      ],
    );
  }
}

/// A multi-select row of the same pills, for "choose all that apply".
class MultiChoicePills<T> extends StatelessWidget {
  const MultiChoicePills({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> options;
  final Set<T> selected;
  final String Function(T option) labelOf;

  /// Receives the new selection; null disables every pill.
  final ValueChanged<Set<T>>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final option in options)
          _Pill(
            label: labelOf(option),
            selected: selected.contains(option),
            onTap: onChanged == null
                ? null
                : () => onChanged!(
                    selected.contains(option)
                        ? ({...selected}..remove(option))
                        : {...selected, option},
                  ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    this.semanticLabel,
    this.onTap,
  });

  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: selected ? AppColors.ink : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(color: Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSizes.minTouchTarget,
              minHeight: AppSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              // The touch-target minimum makes the pill taller (and, for a
              // single digit, wider) than its label, so the label is centred
              // in the spare space instead of sitting at the top left.
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    color: selected ? AppColors.surface : AppColors.ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
