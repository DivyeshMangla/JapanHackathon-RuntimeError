import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/accuracy_chart.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/motor_repository_providers.dart';
import '../domain/motor.dart';
import 'controllers/motor_controllers.dart';
import 'motor_capture_strings.dart';
import 'motor_report_strings.dart';

/// One drawing photo for the therapist: the original on request, the configured
/// model's provisional report, and the therapist's own feedback.
class MotorReviewCard extends ConsumerStatefulWidget {
  const MotorReviewCard({
    super.key,
    required this.patientId,
    required this.submission,
    required this.exerciseName,
  });

  final String patientId;
  final MotorSubmission submission;
  final String? exerciseName;

  @override
  ConsumerState<MotorReviewCard> createState() => _MotorReviewCardState();
}

class _MotorReviewCardState extends ConsumerState<MotorReviewCard> {
  Future<Uint8List>? _photo;
  bool _working = false;
  late bool _detailsVisible = widget.submission.reviewedAt == null;

  Future<void> _change(Future<void> Function() action) async {
    setState(() => _working = true);
    await runWithFailureMessage(context, action);
    if (mounted) setState(() => _working = false);
  }

  Future<void> _review() async {
    final decision = await showDialog<_MotorReviewDecision>(
      context: context,
      builder: (_) => _MotorReviewDialog(submission: widget.submission),
    );
    if (decision == null || !mounted) return;
    setState(() => _working = true);
    final saved = await runWithFailureMessage(
      context,
      () => ref
          .read(motorActionsProvider)
          .review(
            widget.patientId,
            widget.submission.id,
            decision.note,
            outcome: decision.outcome,
          ),
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      if (saved) {
        _photo = null;
        _detailsVisible = false;
      }
    });
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Feedback saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final submission = widget.submission;
    final report = submission.report;
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.exerciseName ?? submission.exerciseId} · ${submission.practiceDay}',
            style: text.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(switch (submission.status) {
            MotorAnalysisStatus.ready => l10n.motorAnalysisReady,
            MotorAnalysisStatus.unavailable => l10n.motorAnalysisUnavailable,
            MotorAnalysisStatus.declined => l10n.motorAnalysisDeclined,
            MotorAnalysisStatus.pending ||
            MotorAnalysisStatus.processing => l10n.motorAnalysisPending,
          }, style: text.bodySmall),
          if (submission.captureFeedback?.replacementRequired == true) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(MotorCaptureStrings.replaceTitle),
          ],
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: l10n.motorViewPhoto,
            icon: LucideIcons.image,
            onPressed: () => setState(() {
              _detailsVisible = true;
              _photo = ref.read(motorRepositoryProvider).photo(submission.id);
            }),
          ),
          if (_photo != null) _Photo(photo: _photo!),
          if (report != null && _detailsVisible) _Report(report: report),
          if (submission.status == MotorAnalysisStatus.unavailable) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: l10n.motorRetryAnalysis,
              icon: LucideIcons.refreshCw,
              onPressed: _working
                  ? null
                  : () => _change(
                      () => ref
                          .read(motorActionsProvider)
                          .retryAnalysis(widget.patientId, submission.id),
                    ),
            ),
          ],
          if (submission.reviewNote != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.motorFeedback(submission.reviewNote!)),
          ],
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: l10n.motorReviewAction,
            icon: LucideIcons.messageSquare,
            onPressed: _working ? null : _review,
          ),
        ],
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.photo});

  final Future<Uint8List> photo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: FutureBuilder<Uint8List>(
        future: photo,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            return InfoNotice(
              error is AppFailure
                  ? l10n.failureMessage(error)
                  : l10n.motorPhotoLoadFailed,
            );
          }
          if (!snapshot.hasData) {
            return const Skeleton(height: AppSizes.signaturePad);
          }
          return Image.memory(
            snapshot.data!,
            cacheWidth: AppSizes.photoPreviewPixels,
            height: AppSizes.qrCode,
            fit: BoxFit.contain,
            semanticLabel: l10n.motorOriginalPhoto,
            errorBuilder: (_, _, _) => Text(l10n.motorInvalidPhoto),
          );
        },
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});

  final MotorReport report;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.imageQuality == 'retake')
            InfoNotice(context.l10n.motorRetake)
          else
            AccuracyChart(
              title: MotorReportStrings.chartTitle,
              notAssessable: MotorReportStrings.notAssessable,
              measures: [
                if (report.expectedCount != null)
                  AccuracyMeasure(
                    '${MotorReportStrings.count} '
                    '${report.observedCount ?? MotorReportStrings.notAssessable}'
                    '/${report.expectedCount}',
                    report.countScore,
                  ),
                AccuracyMeasure(
                  MotorReportStrings.formation,
                  report.formationScore,
                ),
                AccuracyMeasure(
                  MotorReportStrings.alignment,
                  report.alignmentScore,
                ),
                AccuracyMeasure(
                  MotorReportStrings.spacing,
                  report.spacingScore,
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(report.suggestion),
          Text(MotorReportStrings.automated, style: text.bodySmall),
          _ReportDetails(report: report),
        ],
      ),
    );
  }
}

/// The model's full wording stays one tap away for the therapist to verify.
class _ReportDetails extends StatelessWidget {
  const _ReportDetails({required this.report});

  final MotorReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final small = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      title: const Text(MotorReportStrings.details),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(report.observations),
        if (report.countEvidence?.trim().isNotEmpty == true)
          Text('${MotorReportStrings.countEvidence}: ${report.countEvidence}'),
        if (report.expectedResult != null)
          Text(l10n.motorReportTarget(report.expectedResult!)),
        if (report.comparison != null)
          Text(l10n.motorReportComparison(report.comparison!)),
        if (report.evidence != null)
          _ReportEvidence(evidence: report.evidence!),
        const SizedBox(height: AppSpacing.xs),
        if (report.validation != null) Text(report.validation!, style: small),
        for (final limitation in report.limitations)
          Text(limitation, style: small),
        Text(l10n.motorModel(report.model), style: small),
      ],
    );
  }
}

class _ReportEvidence extends StatelessWidget {
  const _ReportEvidence({required this.evidence});
  final MotorEvidence evidence;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (evidence.alignment.isNotEmpty)
        Text('${MotorReportStrings.alignmentEvidence}: ${evidence.alignment}'),
      if (evidence.formation.isNotEmpty)
        Text('${MotorReportStrings.formationEvidence}: ${evidence.formation}'),
      if (evidence.spacing.isNotEmpty)
        Text('${MotorReportStrings.spacingEvidence}: ${evidence.spacing}'),
    ],
  );
}

class _MotorReviewDecision {
  const _MotorReviewDecision(this.note, this.outcome);
  final String note;
  final MotorTherapistOutcome outcome;
}

class _MotorReviewDialog extends StatefulWidget {
  const _MotorReviewDialog({required this.submission});
  final MotorSubmission submission;
  @override
  State<_MotorReviewDialog> createState() => _MotorReviewDialogState();
}

class _MotorReviewDialogState extends State<_MotorReviewDialog> {
  late final _note = TextEditingController(
    text: widget.submission.reviewNote ?? '',
  );
  late MotorTherapistOutcome _outcome = widget.submission.therapistOutcome;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.feedbackTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(MotorReportStrings.shared),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<MotorTherapistOutcome>(
              initialValue: _outcome,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: MotorReportStrings.outcome,
              ),
              items: [
                for (final value in MotorTherapistOutcome.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(switch (value) {
                      MotorTherapistOutcome.onTrack =>
                        MotorReportStrings.onTrack,
                      MotorTherapistOutcome.needsPractice =>
                        MotorReportStrings.needsPractice,
                      MotorTherapistOutcome.notAssessed =>
                        MotorReportStrings.notAssessed,
                    }),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _outcome = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              maxLength: 2000,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.feedbackLabel),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _note.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _MotorReviewDecision(_note.text.trim(), _outcome),
                ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
