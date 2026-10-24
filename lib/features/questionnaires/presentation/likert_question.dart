import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/choice_pills.dart';

/// One numbered statement rated from 1 (strongly disagree) to 5 (strongly
/// agree). The chosen answer is spelled out below the scale so the meaning
/// never depends on the number alone.
class LikertQuestion extends StatelessWidget {
  const LikertQuestion({
    super.key,
    required this.number,
    required this.statement,
    required this.value,
    required this.onChanged,
    this.showMissing = false,
  });

  final int number;
  final String statement;
  final int? value;
  final ValueChanged<int>? onChanged;

  /// Shows the inline "answer this" message while [value] is null.
  final bool showMissing;

  static const _scale = [1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final answer = value;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AppSizes.counterColumn,
                child: Text(
                  number.toString().padLeft(2, '0'),
                  style: AppTypography.mono.copyWith(color: AppColors.seal),
                ),
              ),
              Expanded(child: Text(statement, style: text.bodyLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ChoicePills<int?>(
            options: _scale,
            selected: answer,
            labelOf: (v) => '$v',
            semanticLabelOf: (v) => l10n.agreement(v!),
            onSelected: onChanged == null ? null : (v) => onChanged!(v!),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            answer == null ? l10n.likertAnchors : l10n.agreement(answer),
            style: text.bodySmall,
          ),
          if (showMissing && answer == null)
            Text(
              l10n.answerRequired,
              style: text.bodySmall?.copyWith(color: AppColors.error),
            ),
        ],
      ),
    );
  }
}
