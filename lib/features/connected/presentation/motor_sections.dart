import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../data/connected_service.dart';
import '../domain/connected_models.dart';
import 'motor_practice_page.dart';
import 'patient_sections.dart';

class MotorDailySection extends StatelessWidget {
  const MotorDailySection({
    super.key,
    required this.service,
    required this.record,
  });
  final ConnectedService service;
  final PatientRecord record;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final exercises = [
      for (final id in record.plan!.exerciseIds)
        if (service.config.exercise(id)?.isMotor == true)
          service.config.exercise(id)!,
    ];
    final completed = record.motorSubmissions
        .where((s) => s.practiceDay == today)
        .map((s) => s.exerciseId)
        .toSet();
    return SectionCard(
      title: l10n.motorDailyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.motorDailyProgress(
              exercises.where((e) => completed.contains(e.id)).length,
              exercises.length,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.motorDailyGuidance),
          for (final exercise in exercises) ...[
            const SizedBox(height: AppSpacing.md),
            Text(exercise.description),
            PrimaryButton(
              label: completed.contains(exercise.id)
                  ? l10n.motorPracticeAgain(exercise.name)
                  : l10n.motorStart(exercise.name, exercise.minutes),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => MotorPracticePage(
                    service: service,
                    planId: record.plan!.id,
                    exercise: exercise,
                  ),
                ),
              ),
            ),
          ],
          for (final submission in record.motorSubmissions.take(10)) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '${service.config.exercise(submission.exerciseId)?.name ?? submission.exerciseId} · ${submission.practiceDay}',
            ),
            Text(submission.reviewNote ?? l10n.motorAwaitingReview),
          ],
        ],
      ),
    );
  }
}

class MotorReviewsSection extends StatelessWidget {
  const MotorReviewsSection({
    super.key,
    required this.service,
    required this.submissions,
    required this.onReview,
    required this.onRetry,
  });
  final ConnectedService service;
  final List<MotorSubmission> submissions;
  final void Function(String) onReview;
  final void Function(String) onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionCard(
      title: l10n.motorReviewTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.motorReportCaution),
          if (submissions.isEmpty) Text(l10n.motorEmpty),
          for (final submission in submissions)
            _MotorReview(
              key: ValueKey(submission.id),
              service: service,
              submission: submission,
              onReview: () => onReview(submission.id),
              onRetry: () => onRetry(submission.id),
            ),
        ],
      ),
    );
  }
}

class _MotorReview extends StatefulWidget {
  const _MotorReview({
    super.key,
    required this.service,
    required this.submission,
    required this.onReview,
    required this.onRetry,
  });
  final ConnectedService service;
  final MotorSubmission submission;
  final VoidCallback onReview, onRetry;
  @override
  State<_MotorReview> createState() => _MotorReviewState();
}

class _MotorReviewState extends State<_MotorReview> {
  Future<Uint8List>? _photo;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = widget.submission;
    final report = s.report;
    final status = switch (s.status) {
      'ready' => l10n.motorAnalysisReady,
      'unavailable' => l10n.motorAnalysisUnavailable,
      'declined' => l10n.motorAnalysisDeclined,
      _ => l10n.motorAnalysisPending,
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.service.config.exercise(s.exerciseId)?.name ?? s.exerciseId} · ${s.practiceDay}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(status),
          SecondaryButton(
            label: l10n.motorViewPhoto,
            onPressed: () =>
                setState(() => _photo = widget.service.motorPhoto(s.id)),
          ),
          if (_photo != null)
            FutureBuilder<Uint8List>(
              future: _photo,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text(l10n.motorPhotoLoadFailed);
                if (!snapshot.hasData) return Text(l10n.connectedWorking);
                return Image.memory(
                  snapshot.data!,
                  height: AppSizes.qrCode,
                  fit: BoxFit.contain,
                  semanticLabel: l10n.motorOriginalPhoto,
                  errorBuilder: (_, _, _) => Text(l10n.motorInvalidPhoto),
                );
              },
            ),
          if (report != null) ...[
            if (report.imageQuality == 'retake') InfoNotice(l10n.motorRetake),
            Text(report.observations),
            Text(
              l10n.motorReportMetrics(
                _rating(l10n, report.alignment),
                _rating(l10n, report.formation),
                _rating(l10n, report.spacing),
              ),
            ),
            Text(report.suggestion),
            Text(l10n.motorModel(report.model)),
          ],
          if (s.status == 'unavailable')
            SecondaryButton(
              label: l10n.motorRetryAnalysis,
              onPressed: widget.onRetry,
            ),
          if (s.reviewNote != null) Text(l10n.motorFeedback(s.reviewNote!)),
          SecondaryButton(
            label: l10n.motorReviewAction,
            onPressed: widget.onReview,
          ),
        ],
      ),
    );
  }

  String _rating(AppLocalizations l10n, String value) => switch (value) {
    'emerging' => l10n.motorEmerging,
    'developing' => l10n.motorDeveloping,
    'consistent' => l10n.motorConsistent,
    _ => l10n.motorNotAssessable,
  };
}
