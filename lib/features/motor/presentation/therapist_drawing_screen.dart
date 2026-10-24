import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../therapist/presentation/controllers/caseload_controllers.dart';
import '../../therapist/presentation/participant_detail_screen.dart';
import '../domain/motor.dart';
import 'controllers/motor_controllers.dart';
import 'motor_review_card.dart';

/// The therapist picks a child's drawing tasks and reviews the photos sent.
class TherapistDrawingScreen extends ConsumerWidget {
  const TherapistDrawingScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final participant = ref.watch(caseloadParticipantProvider(patientId));
    final name = participant.value?.patient.name;
    return Scaffold(
      appBar: AppBar(
        title: Text(name == null ? l10n.drawingTitle : l10n.drawingFor(name)),
      ),
      body: AsyncView(
        value: participant,
        data: (participant) {
          if (participant == null) return const ParticipantNotFound();
          final catalogue = ref.watch(motorExercisesProvider);
          final record = ref.watch(motorRecordProvider(patientId));
          return AsyncView(
            value: catalogue,
            data: (catalogue) => AsyncView(
              value: record,
              data: (record) => RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(motorRecordProvider(patientId).future),
                child: PageList(
                  children: [
                    _DrawingPlan(
                      key: ValueKey(record.exerciseIds.join(',')),
                      patientId: patientId,
                      childName: participant.patient.firstName,
                      catalogue: catalogue,
                      record: record,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SectionLabel(l10n.motorReviewTitle),
                    Text(l10n.motorReportCaution),
                    const SizedBox(height: AppSpacing.md),
                    if (record.submissions.isEmpty)
                      InfoNotice(l10n.motorEmpty)
                    else
                      for (final submission in record.submissions) ...[
                        MotorReviewCard(
                          key: ValueKey(submission.id),
                          patientId: patientId,
                          submission: submission,
                          exerciseName: catalogue
                              .where((e) => e.id == submission.exerciseId)
                              .firstOrNull
                              ?.name,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DrawingPlan extends ConsumerStatefulWidget {
  const _DrawingPlan({
    super.key,
    required this.patientId,
    required this.childName,
    required this.catalogue,
    required this.record,
  });

  final String patientId;
  final String childName;
  final List<MotorExercise> catalogue;
  final MotorRecord record;

  @override
  ConsumerState<_DrawingPlan> createState() => _DrawingPlanState();
}

class _DrawingPlanState extends ConsumerState<_DrawingPlan> {
  late final _selected = {...widget.record.exerciseIds};
  bool _saving = false;

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    final saved = await runWithFailureMessage(
      context,
      () => ref
          .read(motorActionsProvider)
          .assign(
            childId: widget.patientId,
            title: l10n.drawingPlanTitle(widget.childName),
            exerciseIds: [
              for (final exercise in widget.catalogue)
                if (_selected.contains(exercise.id)) exercise.id,
            ],
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.drawingPlanSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!widget.record.consented) {
      return InfoNotice(l10n.drawingTherapistNeedsConsent);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.drawingChoose),
        for (final exercise in widget.catalogue) ...[
          InkCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(exercise.name),
              subtitle: Text(exercise.description),
              value: _selected.contains(exercise.id),
              onChanged: _saving
                  ? null
                  : (value) => setState(
                      () => value == true
                          ? _selected.add(exercise.id)
                          : _selected.remove(exercise.id),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: _saving ? l10n.drawingSaving : l10n.drawingSave,
          icon: LucideIcons.check,
          onPressed: _saving || _selected.isEmpty ? null : _save,
        ),
      ],
    );
  }
}
