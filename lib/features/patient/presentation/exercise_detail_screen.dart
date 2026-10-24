import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/entry_cascade.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../exercises/domain/schedule.dart';
import '../../exercises/presentation/caution_note.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import '../../exercises/presentation/demos/exercise_demo_player.dart';
import '../../exercises/presentation/demos/exercise_demos.dart';
import '../../usage/domain/usage_event.dart';
import '../../usage/presentation/usage_tracker.dart';
import 'today_exercises_screen.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final activity = ref.watch(patientActivityProvider(user.id));
    final l10n = context.l10n;

    return UsageTracker(
      action: UsageAction.exerciseOpened,
      detail: exerciseId,
      child: Scaffold(
        appBar: AppBar(),
        body: AsyncView(
          value: activity,
          data: (activity) {
            final exercise = activity.exercises[exerciseId];
            final schedule = activity.currentSchedules
                .where((s) => s.exerciseId == exerciseId)
                .firstOrNull;
            if (exercise == null || schedule == null) {
              return EmptyState(
                icon: LucideIcons.fileQuestion,
                title: l10n.detailNotFoundTitle,
                message: l10n.detailNotFoundBody,
              );
            }
            final today = activity.todayItems
                .where((i) => i.exercise.id == exerciseId)
                .firstOrNull;

            return PageList(
              children: [
                EntryCascade(
                  children: [
                    _Header(exercise: exercise, schedule: schedule),
                    const SizedBox(height: AppSpacing.lg),
                    if (exerciseDemoFor(exercise.id) case final demo?)
                      ExerciseDemoPlayer(
                        demo: demo,
                        repetitions: schedule.repetitions,
                      )
                    else
                      const _MediaPlaceholder(),
                    _Guidance(exercise: exercise, schedule: schedule),
                    if (!schedule.targets.isEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(l10n.detailTargets),
                      _Targets(targets: schedule.targets),
                    ],
                    if (_showsSteps(exercise)) ...[
                      const SizedBox(height: AppSpacing.xl),
                      SectionLabel(l10n.detailSteps),
                      for (final (index, step) in exercise.steps.indexed)
                        _Step(number: index + 1, text: step),
                    ],
                    if (today != null)
                      _TodaySessions(patientId: user.id, item: today),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// A one-sentence exercise whose single step repeats its summary would
  /// show the same text twice, so the steps are left out.
  static bool _showsSteps(Exercise exercise) =>
      exercise.steps.isNotEmpty &&
      !(exercise.steps.length == 1 &&
          exercise.steps.single == exercise.summary);
}

/// The therapist's own instructions, any caution, and the program's note.
class _Guidance extends StatelessWidget {
  const _Guidance({required this.exercise, required this.schedule});

  final Exercise exercise;
  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (schedule.instructions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.therapistInstructions),
          InkCard(child: Text(schedule.instructions, style: text.bodyLarge)),
        ],
        if (exercise.caution.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          CautionNote(text: exercise.caution),
        ],
        if (exercise.programNote.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          SectionLabel(l10n.aboutProgram(exercise.program)),
          Text(exercise.programNote, style: text.bodyMedium),
        ],
      ],
    );
  }
}

/// Today's session count with mark and undo. A voice-diary session is
/// marked by filling in the diary.
class _TodaySessions extends ConsumerWidget {
  const _TodaySessions({required this.patientId, required this.item});

  final String patientId;
  final DayItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final actions = ref.read(completionActionsProvider);
    final isDiary =
        item.exercise.verificationType == VerificationType.voiceDiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.detailSessionsToday(
            item.sessionsDone,
            item.schedule.sessionsPerDay,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (!item.isDone)
          PrimaryButton(
            label: isDiary ? l10n.voiceDiaryOpen : l10n.detailMarkSession,
            icon: isDiary ? LucideIcons.notebookPen : LucideIcons.check,
            onPressed: isDiary
                ? () => context.push(
                    AppRoutes.patientVoiceDiary(item.exercise.id),
                  )
                : () => runWithFailureMessage(
                    context,
                    () => actions.addSession(patientId, item),
                  ),
          ),
        if (item.sessionsDone > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: l10n.detailUndoSession,
            icon: LucideIcons.undo2,
            onPressed: () => runWithFailureMessage(
              context,
              () => actions.removeSession(patientId, item),
            ),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.exercise, required this.schedule});

  final Exercise exercise;
  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exercise.program.toUpperCase(),
          style: text.labelMedium?.copyWith(color: AppColors.seal),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(exercise.title, style: text.headlineLarge),
        const SizedBox(height: AppSpacing.sm),
        ExerciseMeta(
          minutes: exercise.durationMinutes,
          repetitions: schedule.repetitions,
          sessions: schedule.sessionsPerDay,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(exercise.summary, style: text.bodyLarge),
      ],
    );
  }
}

class _Targets extends StatelessWidget {
  const _Targets({required this.targets});

  final ExerciseTargets targets;

  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lines = [
      if (targets.durationSec case final s?) l10n.targetDuration(_number(s)),
      if (targets.pitchHz case final hz?) l10n.targetPitch(_number(hz)),
      if (targets.toleranceCents case final c?)
        l10n.targetTolerance(_number(c)),
      if (targets.rangeSemitones case final st?) l10n.targetRange(_number(st)),
    ];
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.target,
                    size: 16,
                    color: AppColors.seal,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Stands in for a demonstration video, which the prototype does not ship.
class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.pageGradient),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.circlePlay,
                      size: 40,
                      color: AppColors.wash,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.detailVideoTitle,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Text(
                      l10n.detailVideoBody,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSizes.counterColumn,
            child: Text(
              number.toString().padLeft(2, '0'),
              style: AppTypography.mono.copyWith(
                color: AppColors.seal,
                fontWeight: FontWeight.w500,
                height: 1.75,
              ),
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
