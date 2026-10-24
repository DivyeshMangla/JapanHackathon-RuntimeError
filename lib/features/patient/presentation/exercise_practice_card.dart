import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/patient_activity.dart';

/// Lays a card on a numbered rail. The rail turns ink below every finished
/// exercise, so the list reads as a path through the day.
class PracticeTimelineEntry extends StatelessWidget {
  const PracticeTimelineEntry({
    super.key,
    required this.number,
    required this.done,
    required this.featured,
    required this.previousDone,
    required this.isFirst,
    required this.isLast,
    required this.child,
  });

  final int number;
  final bool done;
  final bool featured;
  final bool previousDone;
  final bool isFirst;
  final bool isLast;
  final Widget child;

  static const _node = AppSizes.counterColumn;
  static const _railWidth = 2.0;

  /// Above this text scale the rail would squeeze the card until button
  /// labels break mid-word, so the card takes the full width instead.
  static const _maxRailTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final bottomGap = isLast ? 0.0 : AppSpacing.md;
    if (MediaQuery.textScalerOf(context).scale(1) > _maxRailTextScale) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomGap),
        child: child,
      );
    }
    // Centres the node on the card's 48px header row.
    final nodeTop =
        (featured ? AppSpacing.lg : AppSpacing.md) +
        (AppSizes.minTouchTarget - _node) / 2;
    const railLeft = (_node - _railWidth) / 2;
    return Stack(
      children: [
        if (!isFirst)
          Positioned(
            left: railLeft,
            top: 0,
            height: nodeTop,
            width: _railWidth,
            child: ColoredBox(
              color: previousDone ? AppColors.ink : AppColors.rail,
            ),
          ),
        if (!isLast)
          Positioned(
            left: railLeft,
            top: nodeTop + _node,
            bottom: 0,
            width: _railWidth,
            child: ColoredBox(color: done ? AppColors.ink : AppColors.rail),
          ),
        Positioned(
          left: 0,
          top: nodeTop,
          child: _TimelineNode(number: number, done: done, featured: featured),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: _node + AppSpacing.md,
            bottom: bottomGap,
          ),
          child: child,
        ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.number,
    required this.done,
    required this.featured,
  });

  final int number;
  final bool done;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.standard,
        curve: AppMotion.curve,
        width: AppSizes.counterColumn,
        height: AppSizes.counterColumn,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done
              ? AppColors.sunshine
              : featured
              ? AppColors.ink
              : AppColors.surface,
          shape: BoxShape.circle,
          border: done || featured ? null : Border.all(color: AppColors.rail),
        ),
        child: done
            ? const Icon(LucideIcons.check, size: 16, color: AppColors.ink)
            : Text(
                number.toString().padLeft(2, '0'),
                style: AppTypography.monoSmall.copyWith(
                  color: featured ? AppColors.surface : AppColors.muted,
                ),
              ),
      ),
    );
  }
}

/// One of today's exercises. The first unfinished one is [featured]: a dark
/// card that leads with starting the exercise. The rest are compact white
/// cards whose main action marks the next session.
class ExercisePracticeCard extends StatefulWidget {
  const ExercisePracticeCard({
    super.key,
    required this.item,
    required this.featured,
    required this.onOpen,
    required this.onSession,
  });

  final DayItem item;
  final bool featured;
  final VoidCallback onOpen;
  final Future<void> Function(bool done) onSession;

  @override
  State<ExercisePracticeCard> createState() => _ExercisePracticeCardState();
}

class _ExercisePracticeCardState extends State<ExercisePracticeCard> {
  bool _saving = false;

  Future<void> _mark(bool done) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSession(done);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _CardBody(
      item: widget.item,
      dark: widget.featured,
      saving: _saving,
      onOpen: widget.onOpen,
      onMark: _mark,
    );
    if (!widget.featured) {
      return InkCard(child: body);
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.darkGradient,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: body,
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.item,
    required this.dark,
    required this.saving,
    required this.onOpen,
    required this.onMark,
  });

  final DayItem item;
  final bool dark;
  final bool saving;
  final VoidCallback onOpen;
  final Future<void> Function(bool done) onMark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final exercise = item.exercise;
    final titleColor = dark
        ? AppColors.surface
        : item.isDone
        ? AppColors.muted
        : AppColors.ink;

    if (item.isDone) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.title, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.practiceCompleted, style: text.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.practiceOpenNamed(exercise.title),
            onPressed: onOpen,
            icon: const Icon(LucideIcons.arrowUpRight, size: 20),
          ),
          IconButton(
            tooltip: l10n.practiceUndoNamed(item.sessionsDone, exercise.title),
            onPressed: saving ? null : () => onMark(false),
            icon: const Icon(LucideIcons.undo2, size: 18),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _Chip(
                  label: dark ? l10n.practiceUpNext : exercise.program,
                  dark: dark,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: l10n.practiceOpenNamed(exercise.title),
              onPressed: onOpen,
              style: IconButton.styleFrom(
                backgroundColor: dark
                    ? AppColors.dockSelection
                    : AppColors.washTint,
                foregroundColor: dark ? AppColors.surface : AppColors.ink,
              ),
              icon: const Icon(LucideIcons.arrowUpRight, size: 20),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          exercise.title,
          style: (dark ? text.headlineMedium : text.titleLarge)?.copyWith(
            color: titleColor,
          ),
        ),
        if (dark) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            exercise.program,
            style: text.bodySmall?.copyWith(color: AppColors.onDarkMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DoseBadge(
              icon: LucideIcons.clock,
              label: l10n.practiceMinutes(exercise.durationMinutes),
              dark: dark,
            ),
            _DoseBadge(
              icon: LucideIcons.repeat,
              label: l10n.practiceRepetitions(item.schedule.repetitions),
              dark: dark,
            ),
            if (item.schedule.sessionsPerDay > 1)
              _SessionDots(item: item, dark: dark),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _SessionActions(
          item: item,
          dark: dark,
          saving: saving,
          onOpen: onOpen,
          onMark: onMark,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.dark});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: dark ? AppColors.dockSelection : AppColors.surface,
        border: dark ? null : Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(
              color: dark ? AppColors.sunshine : AppColors.purple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: dark ? AppColors.surface : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseBadge extends StatelessWidget {
  const _DoseBadge({
    required this.icon,
    required this.label,
    required this.dark,
  });

  final IconData icon;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.onDarkMuted : AppColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: AppTypography.monoSmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// One dot per session today, filled as each is marked.
class _SessionDots extends StatelessWidget {
  const _SessionDots({required this.item, required this.dark});

  final DayItem item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final total = item.schedule.sessionsPerDay;
    final label = context.l10n.practiceSessionProgress(
      item.sessionsDone,
      total,
    );
    final pendingBorder = dark ? AppColors.onDarkMuted : AppColors.rail;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppMotion.standard,
              curve: AppMotion.curve,
              width: AppSpacing.md,
              height: AppSpacing.md,
              decoration: BoxDecoration(
                color: i < item.sessionsDone ? AppColors.sunshine : null,
                shape: BoxShape.circle,
                border: i < item.sessionsDone
                    ? null
                    : Border.all(color: pendingBorder, width: 1.5),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: AppTypography.monoSmall.copyWith(
                color: dark ? AppColors.onDarkMuted : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks the next session, or shows the exercise as completed; undo always
/// removes the latest session so counts stay in order.
class _SessionActions extends StatelessWidget {
  const _SessionActions({
    required this.item,
    required this.dark,
    required this.saving,
    required this.onOpen,
    required this.onMark,
  });

  final DayItem item;
  final bool dark;
  final bool saving;
  final VoidCallback onOpen;
  final Future<void> Function(bool done) onMark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = item.sessionsDone;
    final diary = item.exercise.verificationType == VerificationType.voiceDiary;
    const compactSize = Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget);

    final markLabel = saving
        ? l10n.saving
        : diary
        ? l10n.practiceLogDiary
        : item.schedule.sessionsPerDay == 1
        ? l10n.practiceMarkDone
        : l10n.practiceMarkSession(done + 1);
    final markIcon = diary ? LucideIcons.bookOpen : LucideIcons.check;
    final onMarkNext = saving ? null : () => onMark(true);

    final Widget main;
    if (item.isDone) {
      main = _CompletedPill(label: l10n.practiceCompleted);
    } else if (dark) {
      main = OutlinedButton.icon(
        onPressed: onMarkNext,
        style: OutlinedButton.styleFrom(
          minimumSize: compactSize,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.onDarkMuted,
          side: const BorderSide(color: AppColors.dockSelection),
        ),
        icon: Icon(markIcon, size: 18),
        label: _FitLabel(markLabel),
      );
    } else {
      main = OutlinedButton.icon(
        onPressed: onMarkNext,
        style: OutlinedButton.styleFrom(minimumSize: compactSize),
        icon: Icon(markIcon, size: 18),
        label: _FitLabel(markLabel),
      );
    }

    final markRow = Row(
      children: [
        Expanded(child: main),
        if (done > 0) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: l10n.practiceUndoNamed(done, item.exercise.title),
            onPressed: saving ? null : () => onMark(false),
            style: IconButton.styleFrom(
              backgroundColor: dark
                  ? AppColors.dockSelection
                  : AppColors.washTint,
              foregroundColor: dark ? AppColors.surface : AppColors.ink,
            ),
            icon: const Icon(LucideIcons.undo2, size: 20),
          ),
        ],
      ],
    );

    if (!dark) return markRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onOpen,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.sunshine,
            foregroundColor: AppColors.ink,
          ),
          icon: const Icon(LucideIcons.play, size: 18),
          label: _FitLabel(l10n.practiceStart),
        ),
        const SizedBox(height: AppSpacing.sm),
        markRow,
      ],
    );
  }
}

class _CompletedPill extends StatelessWidget {
  const _CompletedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.sunshine,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.circleCheck, size: 18, color: AppColors.ink),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: _FitLabel(
              label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shrinks a single-line label to fit rather than breaking a word across
/// lines at large text sizes.
class _FitLabel extends StatelessWidget {
  const _FitLabel(this.label, {this.style});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, style: style, maxLines: 1),
    );
  }
}
