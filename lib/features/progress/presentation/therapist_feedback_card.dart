import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../domain/family_progress.dart';
import 'progress_strings.dart';

class TherapistFeedbackCard extends StatelessWidget {
  const TherapistFeedbackCard({
    super.key,
    required this.feedback,
    this.audioLoading = false,
    this.playing = false,
    this.onListen,
  });

  final TherapistFeedback feedback;
  final bool audioLoading;
  final bool playing;
  final VoidCallback? onListen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = feedback.reviewedAt;
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            feedback.title ?? ProgressStrings.activity(feedback.activity),
            style: text.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            date == null
                ? feedback.therapistName ?? ProgressStrings.therapist
                : ProgressStrings.reviewed(
                    feedback.therapistName ?? ProgressStrings.therapist,
                    formatDateTime(date),
                  ),
            style: text.bodySmall,
          ),
          Text(
            ProgressStrings.practiceDate(formatFullDate(feedback.practiceAt)),
            style: text.bodySmall,
          ),
          if (feedback.assessment != ClinicianAssessment.notAssessed) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(switch (feedback.assessment) {
              ClinicianAssessment.correct => ProgressStrings.correct,
              ClinicianAssessment.onTrack => ProgressStrings.onTrack,
              _ => ProgressStrings.needsPractice,
            }, style: text.labelLarge),
          ],
          if (feedback.text.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(feedback.text),
          ],
          if (feedback.audioPath != null) ...[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              label: audioLoading
                  ? ProgressStrings.loadingAudio
                  : playing
                  ? ProgressStrings.stop
                  : ProgressStrings.listen,
              icon: playing ? LucideIcons.square : LucideIcons.volume2,
              onPressed: audioLoading ? null : onListen,
            ),
          ],
        ],
      ),
    );
  }
}
