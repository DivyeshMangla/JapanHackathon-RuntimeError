import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/accuracy_chart.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../data/expression_providers.dart';
import '../domain/expression.dart';
import 'expression_face.dart';
import 'expression_strings.dart';

class ExpressionProgressPanel extends ConsumerWidget {
  const ExpressionProgressPanel({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(expressionRecordProvider(patientId)),
    data: (record) => ExpressionHistory(sessions: record.sessions),
  );
}

class ExpressionHistory extends StatelessWidget {
  const ExpressionHistory({super.key, required this.sessions});
  final List<ExpressionSession> sessions;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionLabel(ExpressionStrings.history),
      const Text(ExpressionStrings.caution),
      const SizedBox(height: AppSpacing.md),
      if (sessions.isEmpty) const Text(ExpressionStrings.noSessions),
      for (final session in sessions) ...[
        ExpressionResultCard(session: session),
        const SizedBox(height: AppSpacing.md),
      ],
    ],
  );
}

class ExpressionResultCard extends StatelessWidget {
  const ExpressionResultCard({super.key, required this.session, this.actions});
  final ExpressionSession session;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => InkCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DateFormat.yMMMd().add_jm().format(session.createdAt),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        AccuracyChart(
          title: ExpressionStrings.matched(session.correct, session.total),
          overall: session.accuracy / 100,
          notAssessable: ExpressionStrings.notAssessable,
          measures: [
            for (final count in session.perExpression)
              AccuracyMeasure(
                ExpressionStrings.count(
                  count.feeling,
                  count.correct,
                  count.total,
                ),
                count.total == 0 ? null : count.correct / count.total,
              ),
          ],
        ),
        Text(
          session.assistance == ExpressionAssistance.withHelp
              ? ExpressionStrings.withHelp
              : ExpressionStrings.independent,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        const SectionLabel(ExpressionStrings.feedback),
        Text(session.reviewNote ?? ExpressionStrings.awaiting),
        if (session.reviewedAt != null)
          Text(
            DateFormat.yMMMd().add_jm().format(session.reviewedAt!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(ExpressionStrings.confusions),
          children: [
            if (session.confusions.isEmpty)
              const Text(ExpressionStrings.allMatched),
            for (final item in session.confusions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  ExpressionStrings.confusion(
                    item.expected,
                    item.selected,
                    item.count,
                  ),
                ),
              ),
          ],
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(ExpressionStrings.details),
          children: [
            for (final (index, item) in session.items.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ExpressionFace(
                  picture: ExpressionPicture.fromId(item.pictureId),
                  semanticLabel: ExpressionStrings.pictureLabel(index + 1),
                  size: AppSizes.minTouchTarget,
                ),
                title: Text(
                  ExpressionStrings.answer(item.expected, item.selected),
                ),
              ),
          ],
        ),
        ?actions,
      ],
    ),
  );
}
