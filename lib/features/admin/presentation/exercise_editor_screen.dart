import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/number_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import 'controllers/admin_controllers.dart';
import 'exercise_library_screen.dart';

/// Create or edit a library exercise. Saving any change leaves the exercise
/// pending approval; approval is a separate, explicit step.
class ExerciseEditorScreen extends ConsumerWidget {
  const ExerciseEditorScreen({super.key, this.exerciseId});

  /// Null when creating a new exercise.
  final String? exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final library = ref.watch(exerciseLibraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(exerciseId == null ? l10n.newExercise : l10n.exerciseTitle),
      ),
      body: AsyncView(
        value: library,
        data: (library) => _Form(
          exercise: library.where((e) => e.id == exerciseId).firstOrNull,
        ),
      ),
    );
  }
}

/// All text inputs of the form, seeded from the exercise being edited.
class _Fields {
  _Fields(Exercise? e)
    : title = TextEditingController(text: e?.title),
      program = TextEditingController(text: e?.program),
      summary = TextEditingController(text: e?.summary),
      steps = TextEditingController(text: e?.steps.join('\n')),
      minutes = TextEditingController(text: '${e?.durationMinutes ?? 5}'),
      reps = TextEditingController(text: '${e?.repetitions ?? 10}'),
      sessions = TextEditingController(text: '${e?.sessionsPerDay ?? 1}'),
      evidence = TextEditingController(text: e?.evidenceSource),
      programNote = TextEditingController(text: e?.programNote),
      caution = TextEditingController(text: e?.caution),
      duration = TextEditingController(
        text: _show(e?.defaultTargets.durationSec),
      ),
      pitch = TextEditingController(text: _show(e?.defaultTargets.pitchHz)),
      tolerance = TextEditingController(
        text: _show(e?.defaultTargets.toleranceCents),
      ),
      range = TextEditingController(
        text: _show(e?.defaultTargets.rangeSemitones),
      );

  final TextEditingController title;
  final TextEditingController program;
  final TextEditingController summary;
  final TextEditingController steps;
  final TextEditingController minutes;
  final TextEditingController reps;
  final TextEditingController sessions;
  final TextEditingController evidence;
  final TextEditingController programNote;
  final TextEditingController caution;
  final TextEditingController duration;
  final TextEditingController pitch;
  final TextEditingController tolerance;
  final TextEditingController range;

  static String _show(double? v) => v == null
      ? ''
      : v == v.roundToDouble()
      ? '${v.round()}'
      : '$v';

  ExerciseTargets targets(VerificationType type) {
    double? read(TextEditingController c) => double.tryParse(c.text.trim());
    final timed =
        type == VerificationType.sustained || type == VerificationType.notes;
    return ExerciseTargets(
      durationSec: timed ? read(duration) : null,
      pitchHz: type == VerificationType.notes ? read(pitch) : null,
      toleranceCents: type == VerificationType.notes ? read(tolerance) : null,
      rangeSemitones: type == VerificationType.glide ? read(range) : null,
    );
  }

  /// Applies the inputs to [base], which clears any approval.
  Exercise applyTo(
    Exercise base,
    VerificationType type, {
    required bool needsInstructions,
  }) => base.revise(
    title: title.text.trim(),
    program: program.text.trim(),
    summary: summary.text.trim(),
    steps: [
      for (final line in steps.text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ],
    durationMinutes: int.parse(minutes.text),
    repetitions: int.parse(reps.text),
    sessionsPerDay: int.parse(sessions.text),
    verificationType: type,
    defaultTargets: targets(type),
    evidenceSource: evidence.text.trim(),
    programNote: programNote.text.trim(),
    caution: caution.text.trim(),
    needsInstructions: needsInstructions,
  );

  void dispose() {
    for (final c in [
      title,
      program,
      summary,
      steps,
      minutes,
      reps,
      sessions,
      evidence,
      programNote,
      caution,
      duration,
      pitch,
      tolerance,
      range,
    ]) {
      c.dispose();
    }
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.exercise});

  final Exercise? exercise;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _form = GlobalKey<FormState>();
  late final _fields = _Fields(widget.exercise);
  late VerificationType _type =
      widget.exercise?.verificationType ?? VerificationType.checklist;
  late bool _needsInstructions = widget.exercise?.needsInstructions ?? false;
  bool _busy = false;

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    final succeeded = await runWithFailureMessage(context, action);
    if (!mounted) return;
    if (!succeeded) {
      setState(() => _busy = false);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    context.pop();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final base =
        widget.exercise ??
        Exercise(
          id: 'ex-${const Uuid().v4().substring(0, 8)}',
          title: '',
          program: '',
          summary: '',
          steps: const [],
          durationMinutes: 1,
          repetitions: 1,
        );
    final draft = _fields.applyTo(
      base,
      _type,
      needsInstructions: _needsInstructions,
    );
    await _run(
      () => ref.read(libraryActionsProvider).save(draft),
      context.l10n.savedPendingApproval(draft.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Form(
      key: _form,
      child: PageList(
        children: [
          if (exercise != null) _ApprovalStatus(exercise: exercise),
          _ContentFields(fields: _fields),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            value: _needsInstructions,
            onChanged: (v) => setState(() => _needsInstructions = v),
            title: Text(context.l10n.fieldNeedsInstructions),
            subtitle: Text(context.l10n.fieldNeedsInstructionsHelp),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.md),
          _DosageFields(fields: _fields),
          const SizedBox(height: AppSpacing.lg),
          _VerificationFields(
            fields: _fields,
            type: _type,
            onTypeChanged: (t) => setState(() => _type = t),
          ),
          const SizedBox(height: AppSpacing.xl),
          _EditorActions(
            exercise: exercise,
            busy: _busy,
            onSave: _save,
            onRun: _run,
          ),
        ],
      ),
    );
  }
}

class _ApprovalStatus extends StatelessWidget {
  const _ApprovalStatus({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final approvedAt = exercise.approvedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExerciseStatusChip(status: exercise.status),
          if (approvedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                context.l10n.approvedOnBy(
                  formatDateTime(approvedAt),
                  exercise.approvedBy ?? '',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContentFields extends StatelessWidget {
  const _ContentFields({required this.fields});

  final _Fields fields;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? l10n.fieldRequired : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledTextField(
          label: l10n.fieldName,
          controller: fields.title,
          validator: required,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.fieldProgram,
          hint: l10n.programHint,
          controller: fields.program,
          validator: required,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.fieldSummary,
          controller: fields.summary,
          maxLines: 3,
          validator: required,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.fieldSteps,
          controller: fields.steps,
          maxLines: 8,
          validator: required,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.fieldProgramNote,
          hint: l10n.fieldProgramNoteHint,
          controller: fields.programNote,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.fieldCaution,
          hint: l10n.fieldCautionHint,
          controller: fields.caution,
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.evidenceField,
          hint: l10n.evidenceHint,
          controller: fields.evidence,
        ),
      ],
    );
  }
}

class _DosageFields extends StatelessWidget {
  const _DosageFields({required this.fields});

  final _Fields fields;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, (label, controller)) in [
          (l10n.fieldMinutes, fields.minutes),
          (l10n.fieldReps, fields.reps),
          (l10n.fieldPerDay, fields.sessions),
        ].indexed) ...[
          if (index > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: NumberField(
              label: label,
              controller: controller,
              wholeNumber: true,
            ),
          ),
        ],
      ],
    );
  }
}

class _VerificationFields extends StatelessWidget {
  const _VerificationFields({
    required this.fields,
    required this.type,
    required this.onTypeChanged,
  });

  final _Fields fields;
  final VerificationType type;
  final ValueChanged<VerificationType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final targets = [
      if (type == VerificationType.sustained || type == VerificationType.notes)
        (l10n.defaultDurationField, fields.duration),
      if (type == VerificationType.notes) ...[
        (l10n.defaultPitchField, fields.pitch),
        (l10n.defaultToleranceField, fields.tolerance),
      ],
      if (type == VerificationType.glide)
        (l10n.defaultRangeField, fields.range),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.verificationSection),
        ChoicePills<VerificationType>(
          options: VerificationType.values,
          selected: type,
          labelOf: l10n.verificationLabel,
          onSelected: onTypeChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final (label, controller) in targets)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: NumberField(label: label, controller: controller),
          ),
      ],
    );
  }
}

class _EditorActions extends ConsumerWidget {
  const _EditorActions({
    required this.exercise,
    required this.busy,
    required this.onSave,
    required this.onRun,
  });

  final Exercise? exercise;
  final bool busy;
  final VoidCallback onSave;
  final Future<void> Function(Future<void> Function() action, String message)
  onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final exercise = this.exercise;
    final actions = ref.read(libraryActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exercise?.status == ExerciseStatus.approved)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: InkCard(
              child: Text(
                l10n.approvalWithdrawnNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        PrimaryButton(
          label: busy ? l10n.saving : l10n.save,
          icon: LucideIcons.save,
          onPressed: busy ? null : onSave,
        ),
        if (exercise != null &&
            exercise.status == ExerciseStatus.pendingApproval) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: l10n.approveForAssignment,
            icon: LucideIcons.badgeCheck,
            onPressed: busy
                ? null
                : () => onRun(
                    () => actions.approve(exercise),
                    l10n.exerciseApprovedToast(exercise.title),
                  ),
          ),
        ],
        if (exercise != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: busy
                ? null
                : () => onRun(
                    () => actions.setArchived(exercise, !exercise.archived),
                    exercise.archived
                        ? l10n.exerciseRestoredToast(exercise.title)
                        : l10n.exerciseArchivedToast(exercise.title),
                  ),
            icon: Icon(
              exercise.archived
                  ? LucideIcons.archiveRestore
                  : LucideIcons.archive,
              size: 18,
            ),
            label: Text(exercise.archived ? l10n.restore : l10n.archive),
          ),
        ],
      ],
    );
  }
}
