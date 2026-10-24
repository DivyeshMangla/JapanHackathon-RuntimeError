import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/seal_mark.dart';
import '../../useful_words/presentation/child_word_page.dart';
import '../../useful_words/presentation/word_strings.dart';
import '../data/connected_service.dart';
import '../domain/connected_models.dart';
import 'connected_actions.dart';
import 'consent_page.dart';
import 'home_header_actions.dart';
import 'record_page.dart';

const _defaultPracticeMinutes = 5;
const _maxPracticeMinutes = 60;

/// The patient's home: what to do next until a plan arrives, then the plan's
/// exercises with logging and recording, and progress with feedback.
class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key, required this.service});

  final ConnectedService service;

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage>
    with ConnectedActions {
  String? _notice;

  @override
  ConnectedService get service => widget.service;

  Future<void> _logPractice(CarePlan plan, String exerciseId) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (_) => const _LogPracticeDialog(),
    );
    if (minutes == null || !mounted) return;
    final l10n = context.l10n;
    setState(() => _notice = null);
    final saved = await run(
      'log-$exerciseId',
      () => service.savePractice(
        planId: plan.id,
        exerciseId: exerciseId,
        minutes: minutes,
      ),
    );
    if (saved && mounted) setState(() => _notice = l10n.connectedPracticeSaved);
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final record = service.patientRecord;
    final syncFailure = service.syncFailure;
    final needsConsent = record != null && record.consent == null;
    return ActionPage(
      title: l10n.connectedGreeting(service.user!.name),
      intro: l10n.connectedPatientIntro,
      headerAction: HomeHeaderActions(service: service),
      error:
          error ??
          (syncFailure == null
              ? null
              : l10n.connectedFailureMessage(syncFailure)),
      actions: [
        if (record == null)
          PrimaryButton(
            label: label('retry', l10n.connectedRetry),
            icon: LucideIcons.refreshCw,
            onPressed: action('retry', service.refresh),
          )
        else if (needsConsent)
          PrimaryButton(
            label: l10n.connectedReadConsent,
            icon: LucideIcons.filePen,
            onPressed: () => _open(ConsentPage(service: service)),
          ),
      ],
      children: [
        PrimaryButton(
          label: WordStrings.title,
          icon: LucideIcons.messageCircle,
          onPressed: () => _open(
            ChildWordPage(repository: service.wordsFor(service.user!.id)),
          ),
        ),
        if (_notice != null)
          InfoNotice(_notice!, icon: LucideIcons.circleCheck),
        if (service.outbox.isNotEmpty) OutboxCard(service: service),
        if (record == null)
          _StepCard(
            icon: LucideIcons.cloudOff,
            title: l10n.connectedNotLoadedTitle,
            message: l10n.connectedNotLoadedMessage,
          )
        else if (needsConsent)
          _StepCard(
            icon: LucideIcons.filePen,
            title: l10n.connectedConsentNeededTitle,
            message: l10n.connectedConsentNeededMessage,
          )
        else if (record.plan == null)
          _StepCard(
            icon: LucideIcons.hourglass,
            title: l10n.connectedNextStepTitle,
            message: record.summary.therapistAssigned
                ? l10n.connectedWaitingPlan
                : l10n.connectedWaitingTherapist,
          )
        else ...[
          _PlanCard(plan: record.plan!),
          for (final exerciseId in record.plan!.exerciseIds)
            _ExerciseCard(
              exerciseId: exerciseId,
              exercise: service.config.exercise(exerciseId),
              logLabel: label('log-$exerciseId', l10n.connectedLogPractice),
              // The dialog comes first, so this is not an action itself;
              // only the save after it runs as one.
              onLog: busy
                  ? null
                  : () => unawaited(_logPractice(record.plan!, exerciseId)),
              onRecord: busy
                  ? null
                  : () => _open(
                      RecordPage(
                        service: service,
                        planId: record.plan!.id,
                        exerciseId: exerciseId,
                      ),
                    ),
            ),
          _ProgressCard(record: record),
        ],
      ],
    );
  }
}

/// One step of getting started: what is happening and why.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SealMark(icon: icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(message, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final CarePlan plan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.title,
              style: text.titleLarge?.copyWith(color: AppColors.surface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.connectedSessionsPerDay(plan.sessionsPerDay),
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.sunshine,
              ),
            ),
            if (plan.notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                plan.notes,
                style: text.bodyMedium?.copyWith(color: AppColors.onDarkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exerciseId,
    required this.exercise,
    required this.logLabel,
    required this.onLog,
    required this.onRecord,
  });

  final String exerciseId;

  /// Null when the library no longer lists the plan's exercise.
  final LibraryExercise? exercise;
  final String logLabel;
  final VoidCallback? onLog;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(exercise?.name ?? exerciseId, style: text.titleLarge),
          if (exercise != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(exercise!.description, style: text.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l10n.connectedRecordPractice,
            icon: LucideIcons.mic,
            onPressed: onRecord,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: logLabel,
            icon: LucideIcons.timer,
            onPressed: onLog,
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.record});

  final PatientRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final feedback = [
      for (final recording in record.recordings)
        if (recording.reviewNote != null) recording.reviewNote!,
    ];
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(l10n.connectedProgressTitle),
          Text(
            l10n.connectedProgressSummary(
              record.summary.sessions,
              record.summary.minutes,
            ),
            style: text.bodyMedium,
          ),
          for (final note in feedback) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.connectedTherapistFeedback, style: text.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: text.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Asks how many minutes were practised; pops the number, or null.
class _LogPracticeDialog extends StatefulWidget {
  const _LogPracticeDialog();

  @override
  State<_LogPracticeDialog> createState() => _LogPracticeDialogState();
}

class _LogPracticeDialogState extends State<_LogPracticeDialog> {
  int _minutes = _defaultPracticeMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.connectedLogPracticeTitle),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: l10n.connectedFewerMinutes,
            onPressed: _minutes > 1 ? () => setState(() => _minutes--) : null,
            icon: const Icon(LucideIcons.minus, size: 20),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.connectedMinutes(_minutes),
              style: AppTypography.monoLarge,
            ),
          ),
          IconButton(
            tooltip: l10n.connectedMoreMinutes,
            onPressed: _minutes < _maxPracticeMinutes
                ? () => setState(() => _minutes++)
                : null,
            icon: const Icon(LucideIcons.plus, size: 20),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _minutes),
          child: Text(l10n.connectedSavePractice),
        ),
      ],
    );
  }
}
