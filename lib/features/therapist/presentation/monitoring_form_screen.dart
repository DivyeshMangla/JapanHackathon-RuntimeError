import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../study/domain/monitoring_entry.dart';
import '../../study/presentation/controllers/study_controllers.dart';
import '../domain/participant_study.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_detail_screen.dart';

/// The Adherence and Compliance Monitoring Form for one study week.
class MonitoringFormScreen extends ConsumerWidget {
  const MonitoringFormScreen({
    super.key,
    required this.patientId,
    required this.week,
  });

  final String patientId;
  final int week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final study = ref.watch(participantStudyProvider(patientId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.monitoringFormTitle)),
      body: AsyncView(
        value: study,
        data: (study) {
          if (study == null || week < 1 || week > study.outcome.period.weeks) {
            return const ParticipantNotFound();
          }
          return _MonitoringForm(study: study, week: week);
        },
      ),
    );
  }
}

class _MonitoringForm extends ConsumerStatefulWidget {
  const _MonitoringForm({required this.study, required this.week});

  final ParticipantStudy study;
  final int week;

  @override
  ConsumerState<_MonitoringForm> createState() => _MonitoringFormState();
}

class _MonitoringFormState extends ConsumerState<_MonitoringForm> {
  final _barriers = TextEditingController();
  final _notes = TextEditingController();
  MonitoringRating? _practice;
  MonitoringRating? _schedule;
  MonitoringRating? _technique;
  bool _attempted = false;
  bool _saving = false;

  @override
  void dispose() {
    _barriers.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final practice = _practice;
    final schedule = _schedule;
    final technique = _technique;
    if (practice == null || schedule == null || technique == null) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    final l10n = context.l10n;
    final saved = await runWithFailureMessage(
      context,
      () => ref
          .read(studyRecordActionsProvider)
          .addMonitoring(
            patientId: widget.study.summary.patient.id,
            week: widget.week,
            practice: practice,
            schedule: schedule,
            technique: technique,
            barriers: _barriers.text,
            notes: _notes.text,
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.monitoringSaved)));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final ratings = [
      (
        l10n.monitoringPracticeQuestion,
        _practice,
        (MonitoringRating r) => _practice = r,
      ),
      (
        l10n.monitoringScheduleQuestion,
        _schedule,
        (MonitoringRating r) => _schedule = r,
      ),
      (
        l10n.monitoringTechniqueQuestion,
        _technique,
        (MonitoringRating r) => _technique = r,
      ),
    ];
    return PageList(
      children: [
        Text(widget.study.summary.code, style: AppTypography.participantCode),
        Text(l10n.weekLabel(widget.week), style: text.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        _AppLogReference(study: widget.study, week: widget.week),
        const SizedBox(height: AppSpacing.lg),
        for (final (question, value, assign) in ratings) ...[
          Text(question, style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ChoicePills<MonitoringRating?>(
            options: MonitoringRating.values,
            selected: value,
            labelOf: (r) => l10n.ratingLabel(r!),
            onSelected: _saving ? null : (r) => setState(() => assign(r!)),
          ),
          if (_attempted && value == null)
            Text(
              l10n.chooseOne,
              style: text.bodySmall?.copyWith(color: AppColors.error),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
        LabeledTextField(
          label: l10n.monitoringBarriersLabel,
          controller: _barriers,
          maxLines: 3,
          enabled: !_saving,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.monitoringNotesLabel,
          controller: _notes,
          maxLines: 4,
          enabled: !_saving,
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: _saving ? l10n.saving : l10n.saveMonitoringForm,
          icon: LucideIcons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

/// What the app log and the participant reported for the same week, so the
/// therapist's judgement can be set against them.
class _AppLogReference extends StatelessWidget {
  const _AppLogReference({required this.study, required this.week});

  final ParticipantStudy study;
  final int week;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scored = study.outcome.weeks.where((w) => w.week == week).firstOrNull;
    final report = study.questionnaires.reportForWeek(week);
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.monitoringReference, style: text.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            scored == null
                ? l10n.notScoredYet
                : l10n.sessionsOfPercent(
                    scored.sessionsDone,
                    scored.sessionsDue,
                    formatPercent(scored.adherence),
                  ),
            style: text.bodyMedium,
          ),
          Text(
            report == null
                ? l10n.selfReportMissing
                : l10n.selfReportValue(
                    report.daysPractised,
                    l10n.barrierLabel(report.barrier),
                  ),
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
