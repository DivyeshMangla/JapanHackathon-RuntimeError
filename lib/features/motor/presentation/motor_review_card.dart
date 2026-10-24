import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/feedback_dialog.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/motor_repository_providers.dart';
import '../domain/motor.dart';
import 'controllers/motor_controllers.dart';

/// One drawing photo for the therapist: the original on request, the local
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

  Future<void> _change(Future<void> Function() action) async {
    setState(() => _working = true);
    await runWithFailureMessage(context, action);
    if (mounted) setState(() => _working = false);
  }

  Future<void> _review() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) =>
          FeedbackDialog(initial: widget.submission.reviewNote ?? ''),
    );
    if (note == null || !mounted) return;
    await _change(
      () => ref
          .read(motorActionsProvider)
          .review(widget.patientId, widget.submission.id, note),
    );
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
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: l10n.motorViewPhoto,
            icon: LucideIcons.image,
            onPressed: () => setState(
              () => _photo = ref
                  .read(motorRepositoryProvider)
                  .photo(submission.id),
            ),
          ),
          if (_photo != null) _Photo(photo: _photo!),
          if (report != null) _Report(report: report),
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
    final l10n = context.l10n;
    String rating(String value) => switch (value) {
      'emerging' => l10n.motorEmerging,
      'developing' => l10n.motorDeveloping,
      'consistent' => l10n.motorConsistent,
      _ => l10n.motorNotAssessable,
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (report.imageQuality == 'retake') InfoNotice(l10n.motorRetake),
          Text(report.observations),
          if (report.expectedResult != null)
            Text(l10n.motorReportTarget(report.expectedResult!)),
          if (report.comparison != null)
            Text(l10n.motorReportComparison(report.comparison!)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.motorReportMetrics(
              rating(report.alignment),
              rating(report.formation),
              rating(report.spacing),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(report.suggestion),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.motorModel(report.model),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
