import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/number_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../exercises/domain/schedule.dart';
import '../../exercises/presentation/caution_note.dart';

/// The editable dosage of one exercise: sessions, repetitions, targets and
/// the therapist's instructions. Days are chosen once for the whole form.
class DosageDraft {
  DosageDraft.forExercise(this.exercise)
    : sessions = exercise.sessionsPerDay,
      reps = exercise.repetitions {
    _fillTargets(exercise.defaultTargets);
  }

  DosageDraft.fromSchedule(this.exercise, Schedule schedule)
    : sessions = schedule.sessionsPerDay,
      reps = schedule.repetitions {
    _fillTargets(schedule.targets);
    instructions.text = schedule.instructions;
  }

  final Exercise exercise;
  int sessions;
  int reps;
  final duration = TextEditingController();
  final pitch = TextEditingController();
  final tolerance = TextEditingController();
  final range = TextEditingController();
  final instructions = TextEditingController();

  void _fillTargets(ExerciseTargets targets) {
    String show(double? v) => v == null
        ? ''
        : v == v.roundToDouble()
        ? '${v.round()}'
        : '$v';
    duration.text = show(targets.durationSec);
    pitch.text = show(targets.pitchHz);
    tolerance.text = show(targets.toleranceCents);
    range.text = show(targets.rangeSemitones);
  }

  /// Only the targets that apply to the exercise's verification type are
  /// kept.
  Dosage toDosage(Set<int> weekdays) {
    final type = exercise.verificationType;
    double? value(TextEditingController c) => double.tryParse(c.text.trim());
    final timed =
        type == VerificationType.sustained || type == VerificationType.notes;
    return (
      weekdays: weekdays,
      sessionsPerDay: sessions,
      repetitions: reps,
      targets: ExerciseTargets(
        durationSec: timed ? value(duration) : null,
        pitchHz: type == VerificationType.notes ? value(pitch) : null,
        toleranceCents: type == VerificationType.notes
            ? value(tolerance)
            : null,
        rangeSemitones: type == VerificationType.glide ? value(range) : null,
      ),
      instructions: instructions.text.trim(),
    );
  }

  /// Whether every input would pass its inline validator. Checked directly
  /// because a long, lazily built form never builds, and so never
  /// validates, the fields scrolled out of view.
  bool get isValid {
    if (exercise.needsInstructions && instructions.text.trim().isEmpty) {
      return false;
    }
    return [duration, pitch, tolerance, range].every((c) {
      final text = c.text.trim();
      if (text.isEmpty) return true;
      final value = double.tryParse(text);
      return value != null && value > 0;
    });
  }

  void dispose() {
    for (final c in [duration, pitch, tolerance, range, instructions]) {
      c.dispose();
    }
  }
}

/// Sessions, repetitions, targets and instructions for one exercise.
class DosageFields extends StatelessWidget {
  const DosageFields({super.key, required this.draft, required this.onChanged});

  final DosageDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercise = draft.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DosageStepper(
          label: l10n.sessionsPerDayField,
          value: draft.sessions,
          max: 4,
          onChanged: (v) {
            draft.sessions = v;
            onChanged();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        DosageStepper(
          label: l10n.repsPerSessionField,
          value: draft.reps,
          max: 30,
          onChanged: (v) {
            draft.reps = v;
            onChanged();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SectionLabel(
          l10n.targetsSection(
            l10n.verificationLabel(exercise.verificationType),
          ),
        ),
        TargetFields(draft: draft),
        const SizedBox(height: AppSpacing.md),
        InstructionsSection(draft: draft),
      ],
    );
  }
}

/// Target inputs relevant to the exercise's verification type, each
/// validated inline.
class TargetFields extends StatelessWidget {
  const TargetFields({super.key, required this.draft});

  final DosageDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = Theme.of(context).textTheme.bodySmall;
    final fields = switch (draft.exercise.verificationType) {
      VerificationType.sustained => [
        (l10n.targetDurationField, draft.duration, '10'),
      ],
      VerificationType.notes => [
        (l10n.targetPitchField, draft.pitch, '220'),
        (l10n.targetToleranceField, draft.tolerance, '50'),
        (l10n.targetDurationField, draft.duration, '8'),
      ],
      VerificationType.glide => [(l10n.targetRangeField, draft.range, '12')],
      VerificationType.loudness => null,
      VerificationType.checklist => null,
      VerificationType.voiceDiary => null,
    };
    if (fields == null) {
      return Text(switch (draft.exercise.verificationType) {
        VerificationType.loudness => l10n.loudnessUnavailable,
        VerificationType.voiceDiary => l10n.voiceDiaryNoTarget,
        _ => l10n.checklistNoTarget,
      }, style: note);
    }
    return Column(
      children: [
        for (final (label, controller, example) in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: NumberField(
              label: label,
              controller: controller,
              hint: l10n.exampleHint(example),
            ),
          ),
      ],
    );
  }
}

/// Per-patient instructions, required when the exercise depends on material
/// the clinician chooses, with the exercise's caution shown above them.
class InstructionsSection extends StatelessWidget {
  const InstructionsSection({super.key, required this.draft});

  final DosageDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercise = draft.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exercise.caution.isNotEmpty) ...[
          CautionNote(text: exercise.caution),
          const SizedBox(height: AppSpacing.md),
        ],
        LabeledTextField(
          label: exercise.needsInstructions
              ? l10n.instructionsFieldRequired
              : l10n.instructionsField,
          hint: l10n.instructionsHint,
          controller: draft.instructions,
          maxLines: 4,
          validator: (v) =>
              exercise.needsInstructions && (v ?? '').trim().isEmpty
              ? l10n.instructionsRequired
              : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.instructionsHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// A labelled minus/plus control for small whole numbers from 1 to [max].
class DosageStepper extends StatelessWidget {
  const DosageStepper({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkCard(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          IconButton(
            tooltip: l10n.decrease,
            icon: const Icon(LucideIcons.minus, size: 18),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: AppSizes.counterColumn,
            child: Semantics(
              label: label,
              value: '$value',
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: AppTypography.monoLarge,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.increase,
            icon: const Icon(LucideIcons.plus, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Approved exercises grouped by program, each with a checkbox, for picking
/// several at once.
class ExerciseChecklist extends StatelessWidget {
  const ExerciseChecklist({
    super.key,
    required this.exercises,
    required this.selected,
    required this.onToggle,
  });

  final List<Exercise> exercises;
  final Set<String> selected;
  final ValueChanged<Exercise> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    if (exercises.isEmpty) {
      return Text(
        l10n.allApprovedAssigned,
        style: text.bodyMedium?.copyWith(color: AppColors.muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (program, members) in groupByProgram(exercises)) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(program, style: text.titleSmall),
          ),
          for (final e in members)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ExerciseOption(
                exercise: e,
                selected: selected.contains(e.id),
                onTap: () => onToggle(e),
              ),
            ),
        ],
      ],
    );
  }
}

class _ExerciseOption extends StatelessWidget {
  const _ExerciseOption({
    required this.exercise,
    required this.selected,
    required this.onTap,
  });

  final Exercise exercise;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      checked: selected,
      child: InkCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.title,
                    style: text.titleMedium?.copyWith(
                      color: selected ? AppColors.seal : AppColors.ink,
                    ),
                  ),
                  Text(exercise.summary, style: text.bodySmall, maxLines: 2),
                  if (exercise.caution.isNotEmpty)
                    Text(
                      context.l10n.cautionShort,
                      style: text.bodySmall?.copyWith(color: AppColors.seal),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected ? LucideIcons.squareCheck : LucideIcons.square,
              size: 22,
              color: selected ? AppColors.seal : AppColors.wash,
            ),
          ],
        ),
      ),
    );
  }
}

/// A bar pinned under the content, so the next action is always in reach
/// without scrolling through a long list.
class PinnedActionBar extends StatelessWidget {
  const PinnedActionBar({
    super.key,
    required this.summary,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isError = false,
  });

  final String summary;

  /// Shows [summary] as a problem to fix. Messages go here rather than in a
  /// snackbar, which would cover this bar and its button.
  final bool isError;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                summary,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isError ? AppColors.error : null,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            PrimaryButton(label: label, icon: icon, onPressed: onPressed),
          ],
        ),
      ),
    );
  }
}
