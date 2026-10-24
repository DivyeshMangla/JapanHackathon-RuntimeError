import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../domain/connected_models.dart';

/// The server's limits, checked here first so mistakes show on the field.
const _minAge = 18;
const _maxAge = 120;
const _maxTextLength = 2000;
const _maxTitleLength = 200;
const _maxSessionsPerDay = 5;
const _recentPracticeShown = 10;

/// A titled part of a page laid on the page wash, for forms: white fields
/// and pills would disappear inside a white card.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionLabel(title), child],
      ),
    );
  }
}

/// A titled card holding one part of a page that has no inputs.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionLabel(title), child],
      ),
    );
  }
}

class ConsentSection extends StatelessWidget {
  const ConsentSection({
    super.key,
    required this.consent,
    required this.paperCopy,
    required this.onPaperCopy,
    required this.approveLabel,
    required this.onApprove,
  });

  /// Null until the patient submits consent.
  final ConsentRecord? consent;
  final bool paperCopy;
  final ValueChanged<bool>? onPaperCopy;
  final String approveLabel;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final consent = this.consent;
    if (consent == null) {
      return SectionCard(
        title: l10n.connectedConsentSection,
        child: Text(l10n.connectedNoConsent, style: text.bodySmall),
      );
    }
    final pending = consent.status == ConsentStatus.pending;
    return SectionCard(
      title: l10n.connectedConsentSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.connectedSignedBy(
              consent.signerName,
              DateFormat.yMMMd().format(consent.signedAt.toLocal()),
            ),
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.connectedConsentVersion(consent.version),
            style: AppTypography.monoSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: pending
                  ? l10n.connectedConsentPending
                  : l10n.connectedConsentApproved,
              highlighted: pending,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            consent.analysisAgreed
                ? l10n.connectedAnalysisAgreed
                : l10n.connectedAnalysisDeclined,
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: ColoredBox(
              color: AppColors.washTint,
              child: Image.memory(
                consent.signaturePng,
                height: AppSizes.signaturePreview,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    l10n.connectedSignatureUnavailable,
                    style: text.bodySmall,
                  ),
                ),
              ),
            ),
          ),
          if (pending) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.connectedPaperCopy),
              value: paperCopy,
              onChanged: onPaperCopy == null
                  ? null
                  : (value) => onPaperCopy!(value == true),
            ),
            PrimaryButton(
              label: approveLabel,
              icon: LucideIcons.penLine,
              onPressed: onApprove,
            ),
          ],
        ],
      ),
    );
  }
}

class AssessmentSection extends StatelessWidget {
  const AssessmentSection({
    super.key,
    required this.formKey,
    required this.age,
    required this.demographic,
    required this.clinical,
    required this.enabled,
    required this.saveLabel,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController age;
  final TextEditingController demographic;
  final TextEditingController clinical;
  final bool enabled;
  final String saveLabel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? required(String? value) =>
        (value ?? '').trim().isEmpty ? l10n.connectedFieldRequired : null;
    final textLimit = [LengthLimitingTextInputFormatter(_maxTextLength)];
    return FormSection(
      title: l10n.connectedAssessmentSection,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledTextField(
              label: l10n.connectedAge,
              controller: age,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              enabled: enabled,
              validator: (value) {
                final years = int.tryParse(value ?? '') ?? 0;
                return years < _minAge || years > _maxAge
                    ? l10n.connectedAgeRange
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledTextField(
              label: l10n.connectedDemographic,
              controller: demographic,
              maxLines: 2,
              inputFormatters: textLimit,
              enabled: enabled,
              validator: required,
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledTextField(
              label: l10n.connectedClinical,
              controller: clinical,
              maxLines: 3,
              inputFormatters: textLimit,
              enabled: enabled,
              validator: required,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(label: saveLabel, onPressed: onSave),
          ],
        ),
      ),
    );
  }
}

class PlanSection extends StatelessWidget {
  const PlanSection({
    super.key,
    required this.formKey,
    required this.currentPlan,
    required this.titleController,
    required this.notesController,
    required this.library,
    required this.selected,
    required this.maxExercises,
    required this.sessionsPerDay,
    required this.enabled,
    required this.onSelected,
    required this.onSessionsPerDay,
    required this.saveLabel,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final CarePlan? currentPlan;
  final TextEditingController titleController;
  final TextEditingController notesController;
  final List<LibraryExercise> library;
  final Set<String> selected;
  final int maxExercises;
  final int sessionsPerDay;
  final bool enabled;
  final ValueChanged<Set<String>> onSelected;
  final ValueChanged<int> onSessionsPerDay;
  final String saveLabel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return FormSection(
      title: l10n.connectedPlanSection,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (currentPlan != null) ...[
              Text(
                l10n.connectedCurrentPlan(currentPlan!.title),
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            LabeledTextField(
              label: l10n.connectedPlanTitle,
              controller: titleController,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxTitleLength),
              ],
              enabled: enabled,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? l10n.connectedFieldRequired
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.connectedPlanExercises, style: text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            MultiChoicePills<String>(
              options: [for (final exercise in library) exercise.id],
              selected: selected,
              labelOf: (id) =>
                  library.firstWhere((exercise) => exercise.id == id).name,
              onChanged: enabled
                  ? (selection) {
                      if (selection.length <= maxExercises) {
                        onSelected(selection);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.connectedSessionsPerDayLabel, style: text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            ChoicePills<int>(
              options: [for (var n = 1; n <= _maxSessionsPerDay; n++) n],
              selected: sessionsPerDay,
              labelOf: (n) => '$n',
              semanticLabelOf: l10n.connectedSessionsPerDay,
              onSelected: enabled ? onSessionsPerDay : null,
            ),
            const SizedBox(height: AppSpacing.md),
            LabeledTextField(
              label: l10n.connectedInstructions,
              controller: notesController,
              maxLines: 3,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_maxTextLength),
              ],
              enabled: enabled,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: saveLabel, onPressed: onSave),
          ],
        ),
      ),
    );
  }
}

class PracticeSection extends StatelessWidget {
  const PracticeSection({
    super.key,
    required this.record,
    required this.library,
  });

  final PatientRecord record;
  final ConnectedConfig library;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final date = DateFormat.MMMd();
    return SectionCard(
      title: l10n.connectedPracticeSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.connectedProgressSummary(
              record.summary.sessions,
              record.summary.minutes,
            ),
            style: text.bodyMedium,
          ),
          if (record.practice.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(l10n.connectedNoPractice, style: text.bodySmall),
            ),
          for (final entry in record.practice.take(_recentPracticeShown))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.connectedPracticeLine(
                        library.exercise(entry.exerciseId)?.name ??
                            entry.exerciseId,
                        entry.minutes,
                      ),
                      style: text.bodyMedium,
                    ),
                  ),
                  Text(
                    date.format(entry.completedAt.toLocal()),
                    style: AppTypography.monoSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class RecordingsSection extends StatelessWidget {
  const RecordingsSection({
    super.key,
    required this.recordings,
    required this.library,
    required this.onPlay,
    required this.onStop,
    required this.onReview,
  });

  final List<RecordingSummary> recordings;
  final ConnectedConfig library;
  final VoidCallback? Function(String recordingId) onPlay;
  final VoidCallback onStop;
  final VoidCallback? Function(String recordingId) onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: l10n.connectedRecordingsSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recordings.isEmpty)
            Text(l10n.connectedNoRecordings, style: text.bodySmall),
          for (final (index, recording) in recordings.indexed) ...[
            if (index > 0) const Divider(height: AppSpacing.lg),
            Text(
              l10n.connectedRecordingLine(
                library.exercise(recording.exerciseId)?.name ??
                    recording.exerciseId,
                recording.durationSeconds,
              ),
              style: text.titleMedium,
            ),
            Text(
              DateFormat.yMMMd().format(recording.createdAt.toLocal()),
              style: AppTypography.monoSmall,
            ),
            if (recording.reviewNote != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(recording.reviewNote!, style: text.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                SecondaryButton(
                  label: l10n.play,
                  icon: LucideIcons.play,
                  onPressed: onPlay(recording.id),
                ),
                SecondaryButton(
                  label: l10n.connectedStop,
                  icon: LucideIcons.square,
                  onPressed: onStop,
                ),
                SecondaryButton(
                  label: l10n.connectedAddFeedback,
                  icon: LucideIcons.messageSquareText,
                  onPressed: onReview(recording.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks for a note to the patient; pops the trimmed note, or null.
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = _note.text.trim();
    return AlertDialog(
      title: Text(l10n.connectedFeedbackTitle),
      content: LabeledTextField(
        label: l10n.connectedFeedbackLabel,
        controller: _note,
        maxLines: 4,
        inputFormatters: [LengthLimitingTextInputFormatter(_maxTextLength)],
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: note.isEmpty ? null : () => Navigator.pop(context, note),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
