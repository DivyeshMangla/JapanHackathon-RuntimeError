import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../study/domain/statistics.dart';
import '../../study/domain/study_outcomes.dart';
import 'controllers/admin_controllers.dart';

/// The protocol's outcome measures with the descriptive and paired
/// statistics named in its analysis plan.
class StudyOutcomesScreen extends ConsumerWidget {
  const StudyOutcomesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.outcomesTitle)),
      body: AsyncView(
        value: ref.watch(studyOutcomesProvider),
        data: (outcomes) => PageList(
          children: [
            Text(
              l10n.outcomesIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.primaryOutcomes),
            DescriptiveCard(
              title: l10n.studyAdherence,
              summary: outcomes.adherence,
              unit: '%',
            ),
            const SizedBox(height: AppSpacing.sm),
            DescriptiveCard(
              title: l10n.studyCompliance,
              summary: outcomes.compliance,
              unit: '%',
            ),
            const SizedBox(height: AppSpacing.sm),
            _ProportionCard(
              rows: [(l10n.atOrAboveThreshold, outcomes.atOrAboveThreshold)],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.feasibilitySection),
            _FeasibilityCard(outcomes: outcomes),
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.secondaryOutcomes),
            DescriptiveCard(
              title: l10n.susScoreLabel,
              summary: outcomes.usability,
            ),
            const SizedBox(height: AppSpacing.sm),
            DescriptiveCard(
              title: l10n.satisfactionScaleLabel,
              summary: outcomes.satisfaction,
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.prePostSection),
            _PrePostCard(comparison: outcomes.selfReport),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.voiceMeasuresNote,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// n, mean with standard deviation, and median for one measure.
class DescriptiveCard extends StatelessWidget {
  const DescriptiveCard({
    super.key,
    required this.title,
    required this.summary,
    this.unit = '',
  });

  final String title;
  final Descriptive? summary;

  /// Appended to every value, e.g. "%".
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final s = summary;
    String value(double v) => '${formatDecimal(v, 1)}$unit';
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          if (s == null)
            Text(
              l10n.noDataYet,
              style: text.bodyMedium?.copyWith(color: AppColors.muted),
            )
          else ...[
            Text(
              l10n.meanSd(value(s.mean), s.sd == null ? '–' : value(s.sd!)),
              style: text.titleMedium,
            ),
            Text(l10n.medianN(value(s.median), s.n), style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _ProportionCard extends StatelessWidget {
  const _ProportionCard({required this.rows});

  final List<(String, Proportion?)> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkCard(
      child: Column(
        children: [
          for (final (label, proportion) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(label, style: text.bodyMedium)),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    proportion == null
                        ? l10n.notEntered
                        : l10n.proportionValue(
                            formatPercent(proportion.rate),
                            proportion.count,
                            proportion.total,
                          ),
                    style: text.titleSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FeasibilityCard extends StatelessWidget {
  const _FeasibilityCard({required this.outcomes});

  final StudyOutcomes outcomes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProportionCard(
          rows: [
            (l10n.recruitmentRate, outcomes.recruitment),
            (l10n.retentionRate, outcomes.retention),
            (l10n.usageCompletionRate, outcomes.usageCompletion),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.feasibilityCounts(
            outcomes.enrolled,
            outcomes.completedIntervention,
            outcomes.withdrawn,
          ),
          style: text.bodySmall,
        ),
        Text(l10n.feasibilityDefinitions, style: text.bodySmall),
      ],
    );
  }
}

class _PrePostCard extends StatelessWidget {
  const _PrePostCard({required this.comparison});

  final PrePostComparison comparison;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final t = comparison.tTest;
    final w = comparison.wilcoxon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.prePostHelp, style: text.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        DescriptiveCard(
          title: l10n.prePostBefore,
          summary: comparison.before,
          unit: '%',
        ),
        const SizedBox(height: AppSpacing.sm),
        DescriptiveCard(
          title: l10n.prePostAfter,
          summary: comparison.after,
          unit: '%',
        ),
        const SizedBox(height: AppSpacing.sm),
        InkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.pairedTTest, style: text.titleSmall),
              Text(
                t == null
                    ? l10n.testNotComputable
                    : l10n.tTestResult(
                        formatDecimal(t.meanDifference, 1),
                        formatDecimal(t.t, 3),
                        t.df,
                        formatPValue(t.p),
                      ),
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.wilcoxonTest, style: text.titleSmall),
              Text(
                w == null
                    ? l10n.testNotComputable
                    : l10n.wilcoxonResult(
                        formatDecimal(w.wPlus, 1),
                        formatDecimal(w.wMinus, 1),
                        w.n,
                        formatPValue(w.p),
                        w.exact ? l10n.pExact : l10n.pApproximate,
                      ),
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
