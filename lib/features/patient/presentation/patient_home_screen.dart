import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/entry_cascade.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/seal_mark.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import '../../recordings/presentation/controllers/recording_controllers.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/presentation/controllers/reminder_controllers.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final activity = ref.watch(patientActivityProvider(user.id));
    final probe = ref.watch(probeDueProvider(user.id)).value;
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          value: activity,
          data: (activity) => PageList(
            children: [
              EntryCascade(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  _HomeGreeting(firstName: user.firstName, now: now),
                  const SizedBox(height: AppSpacing.xl),
                  _TodayCard(
                    done: activity.todayAdherence.done,
                    due: activity.todayAdherence.due,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (probe != null && probe.isDueOn(now)) ...[
                    _ProbeDueCard(baseline: probe.isBaseline),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _StreakAndReminder(
                    userId: user.id,
                    streak: activity.streak,
                    now: now,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const InkCard(
                    child: Column(
                      children: [
                        _RecordShortcut(),
                        Divider(height: AppSpacing.lg),
                        _LearnShortcut(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({required this.firstName, required this.now});

  final String firstName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SealMark(size: 48),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.greeting(now, firstName),
                    style: text.titleMedium,
                  ),
                  Text(formatLongDate(now), style: text.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.homeNextReminder,
              onPressed: () => context.go(
                AppRoutes.patientProfileReminders,
                extra: Object(),
              ),
              icon: const Icon(LucideIcons.bell),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          context.l10n.homePracticeHeading.replaceAll('\n', ' '),
          style: text.headlineMedium,
        ),
      ],
    );
  }
}

class _StreakAndReminder extends ConsumerWidget {
  const _StreakAndReminder({
    required this.userId,
    required this.streak,
    required this.now,
  });

  final String userId;
  final int streak;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final reminders = ref.watch(reminderTimesProvider(userId)).value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: StatTile(
            icon: LucideIcons.flame,
            label: l10n.homeStreak,
            value: '$streak',
            caption: l10n.homeStreakDays(streak),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 6,
          child: _NextReminderTile(times: reminders ?? const [], now: now),
        ),
      ],
    );
  }
}

class _RecordShortcut extends StatelessWidget {
  const _RecordShortcut();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => context.go(AppRoutes.patientRecord),
      leading: const Icon(LucideIcons.mic, size: 22),
      title: Text(l10n.homeRecordTitle, style: text.titleMedium),
      subtitle: Text(l10n.homeRecordSubtitle, style: text.bodySmall),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
    );
  }
}

class _LearnShortcut extends StatelessWidget {
  const _LearnShortcut();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => context.go(AppRoutes.patientLearn),
      leading: const Icon(LucideIcons.bookOpen, size: 22),
      title: Text(l10n.learnTitle, style: text.titleMedium),
      subtitle: Text(l10n.homeLearnSubtitle, style: text.bodySmall),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
    );
  }
}

class _ProbeDueCard extends StatelessWidget {
  const _ProbeDueCard({required this.baseline});

  final bool baseline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.audioLines, color: AppColors.seal),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  baseline ? l10n.homeBaselineDue : l10n.homeProbeDue,
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.homeProbeBody, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: l10n.homeProbeStart,
            icon: LucideIcons.mic,
            onPressed: () => context.go(AppRoutes.patientRecord),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.done, required this.due});

  final int done;
  final int due;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final finished = due > 0 && done >= due;
    final message = due == 0
        ? l10n.homeNothingToday
        : finished
        ? l10n.homeAllDone
        : l10n.homeLeftToday(due - done);

    final rate = due == 0 ? 0.0 : (done / due).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: l10n.exercisesSeeProgress,
      child: InkWell(
        onTap: () =>
            context.go(AppRoutes.patientProfileProgress, extra: Object()),
        borderRadius: BorderRadius.circular(AppRadius.base),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.darkGradient,
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.homeTodayTitle,
                      style: text.titleLarge?.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.arrowUpRight,
                    color: AppColors.surface,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final ring = Semantics(
                    label: l10n.homeTodayTitle,
                    value: formatPercent(rate),
                    child: SizedBox.square(
                      dimension: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: rate,
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                              color: AppColors.sunshine,
                              backgroundColor: AppColors.surface,
                            ),
                          ),
                          Text(
                            formatPercent(rate),
                            style: text.headlineMedium?.copyWith(
                              color: AppColors.surface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$done${l10n.homeOfDue(due)}',
                        style: text.headlineSmall?.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        message,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.onDarkMuted,
                        ),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 270 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ring,
                        const SizedBox(height: AppSpacing.lg),
                        details,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      ring,
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
              if (due > 0 && !finished) ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sunshine,
                      foregroundColor: AppColors.ink,
                    ),
                    label: Text(done == 0 ? l10n.homeStart : l10n.homeContinue),
                    icon: const Icon(LucideIcons.arrowRight),
                    onPressed: () => context.go(AppRoutes.patientExercises),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NextReminderTile extends StatelessWidget {
  const _NextReminderTile({required this.times, required this.now});

  final List<ReminderTime> times;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (times.isEmpty) {
      return StatTile(
        onTap: () =>
            context.go(AppRoutes.patientProfileReminders, extra: Object()),
        icon: LucideIcons.bellOff,
        label: l10n.homeNextReminder,
        value: l10n.homeNoReminder,
        caption: l10n.homeSetReminder,
      );
    }
    final next = times
        .map((t) => t.nextAfter(now))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final isToday = next.day == now.day && next.month == now.month;
    return StatTile(
      onTap: () =>
          context.go(AppRoutes.patientProfileReminders, extra: Object()),
      icon: LucideIcons.bell,
      label: l10n.homeNextReminder,
      value: formatClock(next),
      caption: isToday ? l10n.homeToday : l10n.homeTomorrow,
    );
  }
}
