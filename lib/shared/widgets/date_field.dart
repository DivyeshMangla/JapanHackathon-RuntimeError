import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatting.dart';
import '../../core/utils/l10n.dart';
import 'ink_card.dart';

/// A labelled date picker that shows the chosen date or a prompt, with an
/// inline error message underneath when [errorText] is set.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? errorText;

  Future<void> _pick(BuildContext context) async {
    final initial = value ?? lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: label,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final error = errorText;
    final date = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: text.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          button: true,
          label: label,
          child: InkCard(
            onTap: () => _pick(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTouchTarget - 2 * AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.calendar,
                    size: 18,
                    color: AppColors.wash,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      date == null
                          ? context.l10n.chooseDate
                          : formatFullDate(date),
                      style: text.bodyLarge?.copyWith(
                        color: date == null ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(error, style: text.bodySmall?.copyWith(color: AppColors.error)),
        ],
      ],
    );
  }
}
