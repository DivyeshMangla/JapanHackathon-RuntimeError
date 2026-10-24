import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../domain/participant_study.dart';
import 'assessment_widgets.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_detail_screen.dart';
import 'questionnaire_results.dart';
import 'voice_diary_list.dart';

/// Baseline, intervention and follow-up assessment for one participant.
/// Each study week sets the application log beside the participant's
/// self-report and the therapist's monitoring form.
class AssessmentScreen extends ConsumerWidget {
  const AssessmentScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final study = ref.watch(participantStudyProvider(patientId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.assessmentTitle)),
      body: AsyncView(
        value: study,
        data: (study) => study == null
            ? const ParticipantNotFound()
            : _AssessmentBody(study: study),
      ),
    );
  }
}

class _AssessmentBody extends StatelessWidget {
  const _AssessmentBody({required this.study});

  final ParticipantStudy study;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final patientId = study.summary.patient.id;
    final period = study.outcome.period;
    final baselineReport = study.questionnaires.baseline;
    return PageList(
      children: [
        Text(study.summary.code, style: AppTypography.participantCode),
        Text(
          study.summary.patient.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        StudyPhaseText(record: study.record, period: period),
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.baselineSection),
        ChecklistCard(
          items: [
            for (final MapEntry(:key, :value) in study.baseline.entries)
              (l10n.baselineItemLabel(key), value),
          ],
        ),
        if (baselineReport != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.baselineReportSummary(
              baselineReport.daysPractised,
              l10n.barrierLabel(baselineReport.barrier),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: l10n.editStudyRecord,
          icon: LucideIcons.clipboardPen,
          onPressed: () =>
              context.push(AppRoutes.therapistStudyRecord(patientId)),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionLabel(l10n.interventionSection),
        _OutcomeTiles(study: study),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.outcomeDefinitions,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        for (var week = 1; week <= period.weeks; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: WeekCard(study: study, week: week),
          ),
        if (study.voiceDiary.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.voiceDiaryTitle),
          VoiceDiaryList(entries: study.voiceDiary),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionLabel(l10n.followUpSection),
        ChecklistCard(
          items: [
            for (final MapEntry(:key, :value) in study.followUp.entries)
              (l10n.followUpItemLabel(key), value),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        QuestionnaireResults(questionnaires: study.questionnaires),
      ],
    );
  }
}

class _OutcomeTiles extends StatelessWidget {
  const _OutcomeTiles({required this.study});

  final ParticipantStudy study;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outcome = study.outcome;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: StatTile(
            icon: LucideIcons.chartColumn,
            label: l10n.studyAdherence,
            value: formatPercent(outcome.adherence),
            caption: l10n.sessionsOf(outcome.sessionsDone, outcome.sessionsDue),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 5,
          child: StatTile(
            icon: LucideIcons.calendarCheck,
            label: l10n.studyCompliance,
            value: formatPercent(outcome.compliance),
            caption: l10n.daysOf(outcome.fullDoseDays, outcome.prescribedDays),
          ),
        ),
      ],
    );
  }
}
