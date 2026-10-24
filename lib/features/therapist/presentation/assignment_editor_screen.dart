import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/schedule.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import '../../exercises/presentation/weekday_picker.dart';
import 'assignment_widgets.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_detail_screen.dart';

/// Assign new exercises to a patient, or change the dosage and targets of a
/// current assignment. Changes apply from today; past days keep the version
/// that was active then.
class AssignmentEditorScreen extends ConsumerWidget {
  const AssignmentEditorScreen({
    super.key,
    required this.patientId,
    this.scheduleId,
  });

  final String patientId;

  /// The current version being edited, or null to assign new exercises.
  final String? scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final participant = ref.watch(caseloadParticipantProvider(patientId));
    final library = ref.watch(exerciseLibraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          scheduleId == null ? l10n.assignExercise : l10n.editAssignmentTitle,
        ),
      ),
      body: AsyncView(
        value: participant,
        data: (participant) {
          if (participant == null) return const ParticipantNotFound();
          final activity = participant.activity;
          final existing = activity.currentSchedules
              .where((s) => s.id == scheduleId)
              .firstOrNull;
          if (existing != null) {
            return _EditAssignment(
              participantCode: participant.code,
              existing: existing,
              exercise: activity.exercises[existing.exerciseId]!,
            );
          }
          return AsyncView(
            value: library,
            data: (library) => _NewAssignments(
              patientId: patientId,
              participantCode: participant.code,
              exercises: [
                for (final e in library)
                  if (e.isAssignable &&
                      !activity.currentSchedules.any(
                        (s) => s.exerciseId == e.id,
                      ))
                    e,
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _Step { choose, configure }

/// Two steps: tick any number of exercises, then set the days once and the
/// dosage for each. The next action stays pinned to the bottom of the
/// screen, so a long library never has to be scrolled to reach it.
class _NewAssignments extends ConsumerStatefulWidget {
  const _NewAssignments({
    required this.patientId,
    required this.participantCode,
    required this.exercises,
  });

  final String patientId;
  final String participantCode;

  /// Approved exercises the patient does not already have.
  final List<Exercise> exercises;

  @override
  ConsumerState<_NewAssignments> createState() => _NewAssignmentsState();
}

class _NewAssignmentsState extends ConsumerState<_NewAssignments> {
  final _form = GlobalKey<FormState>();
  final _selected = <String>{};
  final _drafts = <String, DosageDraft>{};
  _Step _step = _Step.choose;
  Set<int> _days = const {1, 2, 3, 4, 5, 6, 7};
  bool _attempted = false;

  /// Titles of exercises with inputs to fix, from the last attempt.
  List<String> _invalid = const [];
  bool _saving = false;

  @override
  void dispose() {
    for (final draft in _drafts.values) {
      draft.dispose();
    }
    super.dispose();
  }

  /// Selected exercises in library order, each with its draft dosage.
  List<DosageDraft> get _chosen => [
    for (final (_, members) in groupByProgram(widget.exercises))
      for (final e in members)
        if (_selected.contains(e.id))
          _drafts.putIfAbsent(e.id, () => DosageDraft.forExercise(e)),
  ];

  void _toggle(Exercise exercise) => setState(() {
    if (!_selected.remove(exercise.id)) _selected.add(exercise.id);
  });

  Future<void> _assignAll() async {
    final l10n = context.l10n;
    final drafts = _chosen;
    _form.currentState!.validate();
    final invalid = [
      for (final d in drafts)
        if (!d.isValid) d.exercise.title,
    ];
    setState(() {
      _attempted = true;
      _invalid = invalid;
    });
    if (invalid.isNotEmpty) return;
    setState(() => _saving = true);
    final therapistId = ref.read(currentUserProvider).id;
    final actions = ref.read(scheduleActionsProvider);
    final assigned = <String>[];
    final succeeded = await runWithFailureMessage(context, () async {
      for (final draft in drafts) {
        await actions.assign(
          patientId: widget.patientId,
          exercise: draft.exercise,
          dosage: draft.toDosage(_days),
          therapistId: therapistId,
        );
        assigned.add(draft.exercise.id);
      }
    });
    if (!mounted) return;
    if (succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exercisesAssigned(assigned.length))),
      );
      context.pop();
      return;
    }
    // Whatever was saved before the failure is now assigned, so it leaves
    // the selection rather than being assigned twice on retry.
    setState(() {
      _selected.removeAll(assigned);
      _saving = false;
      if (_selected.isEmpty) _step = _Step.choose;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = _selected.length;
    final configuring = _step == _Step.configure && count > 0;
    return Column(
      children: [
        Expanded(
          child: configuring
              ? Form(
                  key: _form,
                  // After a failed attempt, fields scrolled into view later
                  // show their message as soon as they are built.
                  autovalidateMode: _attempted
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
                  child: _ConfigureStep(
                    participantCode: widget.participantCode,
                    drafts: _chosen,
                    days: _days,
                    enabled: !_saving,
                    onDaysChanged: (days) => setState(() => _days = days),
                    onChanged: () => setState(() {}),
                    onChangeSelection: () =>
                        setState(() => _step = _Step.choose),
                  ),
                )
              : PageList(
                  children: [
                    Text(
                      widget.participantCode,
                      style: AppTypography.participantCode,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.chooseExercisesHint,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ExerciseChecklist(
                      exercises: widget.exercises,
                      selected: _selected,
                      onToggle: _toggle,
                    ),
                  ],
                ),
        ),
        if (count > 0)
          PinnedActionBar(
            summary: configuring && _invalid.isNotEmpty
                ? l10n.fixFieldsFor(_invalid.join(', '))
                : l10n.exercisesSelected(count),
            isError: configuring && _invalid.isNotEmpty,
            label: configuring
                ? (_saving ? l10n.assigning : l10n.assignAction)
                : l10n.continueAction,
            icon: configuring ? LucideIcons.check : LucideIcons.arrowRight,
            onPressed: _saving
                ? null
                : configuring
                ? _assignAll
                : () => setState(() => _step = _Step.configure),
          ),
      ],
    );
  }
}

/// Days for every chosen exercise, then one dosage section per exercise.
class _ConfigureStep extends StatelessWidget {
  const _ConfigureStep({
    required this.participantCode,
    required this.drafts,
    required this.days,
    required this.enabled,
    required this.onDaysChanged,
    required this.onChanged,
    required this.onChangeSelection,
  });

  final String participantCode;
  final List<DosageDraft> drafts;
  final Set<int> days;
  final bool enabled;
  final ValueChanged<Set<int>> onDaysChanged;
  final VoidCallback onChanged;
  final VoidCallback onChangeSelection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return PageList(
      children: [
        Text(participantCode, style: AppTypography.participantCode),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.configureExercises(drafts.length), style: text.titleMedium),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled ? onChangeSelection : null,
            icon: const Icon(LucideIcons.arrowLeft, size: 18),
            label: Text(l10n.changeSelection),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionLabel(l10n.daysSection),
        WeekdayPicker(selected: days, onChanged: onDaysChanged),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.daysApplyToAll, style: text.bodySmall),
        for (final draft in drafts) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(draft.exercise.title, style: text.headlineSmall),
          Text(draft.exercise.program, style: text.bodySmall),
          const SizedBox(height: AppSpacing.md),
          DosageFields(draft: draft, onChanged: onChanged),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.changesFromToday, style: text.bodySmall),
      ],
    );
  }
}

/// Changes one current assignment: days, dosage, targets and instructions,
/// or ends it.
class _EditAssignment extends ConsumerStatefulWidget {
  const _EditAssignment({
    required this.participantCode,
    required this.existing,
    required this.exercise,
  });

  final String participantCode;
  final Schedule existing;
  final Exercise exercise;

  @override
  ConsumerState<_EditAssignment> createState() => _EditAssignmentState();
}

class _EditAssignmentState extends ConsumerState<_EditAssignment> {
  final _form = GlobalKey<FormState>();
  late final _draft = DosageDraft.fromSchedule(
    widget.exercise,
    widget.existing,
  );
  late Set<int> _days = widget.existing.weekdays;
  bool _saving = false;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final succeeded = await runWithFailureMessage(
      context,
      () => ref
          .read(scheduleActionsProvider)
          .revise(
            widget.existing,
            _draft.toDosage(_days),
            therapistId: ref.read(currentUserProvider).id,
          ),
    );
    if (!mounted) return;
    succeeded ? context.pop() : setState(() => _saving = false);
  }

  Future<void> _end() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.endAssignmentTitle),
        content: Text(l10n.endAssignmentBody(widget.exercise.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.endAssignment),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final succeeded = await runWithFailureMessage(
      context,
      () => ref.read(scheduleActionsProvider).end(widget.existing),
    );
    if (!mounted) return;
    succeeded ? context.pop() : setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Form(
      key: _form,
      child: PageList(
        children: [
          Text(widget.participantCode, style: AppTypography.participantCode),
          const SizedBox(height: AppSpacing.md),
          Text(widget.exercise.title, style: text.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.daysSection),
          WeekdayPicker(
            selected: _days,
            onChanged: (days) => setState(() => _days = days),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.dosageSection),
          DosageFields(draft: _draft, onChanged: () => setState(() {})),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _saving ? l10n.saving : l10n.saveChanges,
            icon: LucideIcons.check,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: _saving ? null : _end,
            icon: const Icon(LucideIcons.circleStop, size: 18),
            label: Text(l10n.endAssignment),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.changesFromToday, style: text.bodySmall),
        ],
      ),
    );
  }
}
