import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../exercises/domain/adherence.dart';
import '../../exercises/domain/patient_activity.dart';

const _stripDays = 7;

/// Above this many sessions, segments get too thin to read and the bar
/// becomes continuous.
const _maxSegments = 12;

/// The last seven days as a strip, then today's session count and the time
/// left. Remaining time uses each assignment's duration per session.
class PracticeDaySummary extends StatelessWidget {
  const PracticeDaySummary({super.key, required this.activity});

  final PatientActivity activity;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final today = activity.todayAdherence;
    final week = activity.days.length > _stripDays
        ? activity.days.sublist(activity.days.length - _stripDays)
        : activity.days;
    final remainingMinutes = activity.todayItems.fold<int>(
      0,
      (sum, item) =>
          sum +
          item.exercise.durationMinutes *
              (item.schedule.sessionsPerDay - item.sessionsDone),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (index, day) in week.indexed) ...[
              if (index > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _DayPill(day: day, isToday: index == week.length - 1),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                today.isComplete ? l10n.practiceComplete : l10n.practiceReady,
                style: text.headlineSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _CountPill(done: today.done, due: today.due),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _SessionBar(done: today.done, due: today.due),
        const SizedBox(height: AppSpacing.sm),
        Text(
          today.isComplete
              ? l10n.practiceAllDone
              : l10n.practiceRemainingTime(remainingMinutes),
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// One day of the strip: the weekday above a numbered disc. A fully practised
/// day fills the disc lime, today fills it ink.
class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.isToday});

  final AdherencePeriod day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final date = formatDayMonth(day.start);
    final rest = day.due == 0;
    final discColor = isToday
        ? AppColors.ink
        : day.isComplete
        ? AppColors.sealSelection
        : rest
        ? null
        : AppColors.washTint;
    final numberColor = isToday
        ? AppColors.surface
        : rest
        ? AppColors.muted
        : AppColors.ink;

    return Semantics(
      label: rest
          ? l10n.practiceDayRest(date)
          : l10n.practiceDayStatus(date, day.done, day.due),
      selected: isToday,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isToday ? AppColors.surface : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatWeekdayShort(day.start),
                style: text.labelSmall?.copyWith(
                  color: isToday ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: AppSizes.counterColumn,
              height: AppSizes.counterColumn,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: discColor,
                shape: BoxShape.circle,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${day.start.day}',
                  style: text.labelSmall?.copyWith(
                    color: numberColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.done, required this.due});

  final int done;
  final int due;

  @override
  Widget build(BuildContext context) {
    final finished = due > 0 && done >= due;
    return Semantics(
      label: context.l10n.practiceSessionProgress(done, due),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: finished ? AppColors.sunshine : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              finished ? LucideIcons.check : LucideIcons.listChecks,
              size: 16,
              color: AppColors.ink,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('$done/$due', style: AppTypography.monoLarge),
          ],
        ),
      ),
    );
  }
}

/// One segment per session due, so each tick-off visibly fills a block.
class _SessionBar extends StatelessWidget {
  const _SessionBar({required this.done, required this.due});

  final int done;
  final int due;

  @override
  Widget build(BuildContext context) {
    if (due == 0 || due > _maxSegments) {
      return ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: due == 0 ? 0 : done / due,
            minHeight: AppSizes.progressThick,
            color: AppColors.ink,
            backgroundColor: AppColors.surface,
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < due; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.standard,
                curve: AppMotion.curve,
                height: AppSizes.progressThick,
                decoration: BoxDecoration(
                  color: i < done ? AppColors.ink : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
