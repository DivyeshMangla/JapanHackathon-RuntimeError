import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../study/domain/intervention_outcome.dart';
import '../../study/domain/monitoring_entry.dart';
import '../../study/domain/participant_record.dart';
import '../../study/domain/study_period.dart';
import '../domain/participant_study.dart';

/// Withdrawn, not started, in a given week, or ended.
class StudyPhaseText extends StatelessWidget {
  const StudyPhaseText({super.key, required this.record, required this.period});

  final ParticipantRecord record;
  final StudyPeriod period;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.studyPhase(record, period, DateTime.now()),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
    );
  }
}

/// Assessment steps with a done or to-do mark spelled out in words.
class ChecklistCard extends StatelessWidget {
  const ChecklistCard({super.key, required this.items});

  final List<(String, bool)> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (final (label, done) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    done ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 18,
                    color: done ? AppColors.seal : AppColors.wash,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(label, style: text.bodyMedium)),
                  Text(
                    done ? l10n.checklistDone : l10n.checklistToDo,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One study week: application log, recordings, self-report and the
/// therapist's monitoring form.
class WeekCard extends StatelessWidget {
  const WeekCard({super.key, required this.study, required this.week});

  final ParticipantStudy study;
  final int week;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final period = study.outcome.period;
    final scored = study.outcome.weeks.where((w) => w.week == week).firstOrNull;
    final report = study.questionnaires.reportForWeek(week);
    final forms = study.monitoringForWeek(week);
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.weekLabel(week), style: text.titleMedium),
          Text(
            '${formatShortDate(period.weekStart(week))} – '
            '${formatShortDate(period.weekEnd(week))}',
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabelValue(l10n.sourceAppLog, _appLog(l10n, scored)),
          _LabelValue(
            l10n.sourceFullDose,
            scored == null
                ? l10n.notScoredYet
                : l10n.daysOfPercent(
                    scored.fullDoseDays,
                    scored.prescribedDays,
                    formatPercent(scored.compliance),
                  ),
          ),
          _LabelValue(
            l10n.sourceRecordings,
            '${study.practiceRecordingsInWeek(week)}',
          ),
          _LabelValue(
            l10n.sourceSelfReport,
            report == null
                ? l10n.notSubmitted
                : l10n.selfReportValue(
                    report.daysPractised,
                    l10n.barrierLabel(report.barrier),
                  ),
          ),
          if (report != null && report.note.isNotEmpty)
            _LabelValue(l10n.selfReportNoteShort, report.note),
          for (final form in forms) _MonitoringSummary(entry: form),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: forms.isEmpty
                ? l10n.addMonitoringForm
                : l10n.addAnotherMonitoringForm,
            icon: LucideIcons.clipboardPlus,
            onPressed: () => context.push(
              AppRoutes.therapistMonitoringForm(study.summary.patient.id, week),
            ),
          ),
        ],
      ),
    );
  }

  String _appLog(AppLocalizations l10n, WeekOutcome? scored) {
    if (scored == null) return l10n.notScoredYet;
    return l10n.sessionsOfPercent(
      scored.sessionsDone,
      scored.sessionsDue,
      formatPercent(scored.adherence),
    );
  }
}

class _MonitoringSummary extends StatelessWidget {
  const _MonitoringSummary({required this.entry});

  final MonitoringEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LabelValue(
          l10n.sourceTherapist,
          l10n.monitoringSummary(
            l10n.ratingLabel(entry.practice),
            l10n.ratingLabel(entry.schedule),
            l10n.ratingLabel(entry.technique),
          ),
        ),
        if (entry.barriers.isNotEmpty)
          _LabelValue(l10n.monitoringBarriersLabel, entry.barriers),
        if (entry.notes.isNotEmpty)
          _LabelValue(l10n.monitoringNotesLabel, entry.notes),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: text.bodySmall)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(flex: 3, child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
