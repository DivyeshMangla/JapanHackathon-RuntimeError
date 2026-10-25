import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../useful_words/presentation/word_audio_controller.dart';
import '../domain/family_progress.dart';
import 'controllers/progress_controllers.dart';
import 'progress_strings.dart';
import 'progress_summary.dart';
import 'therapist_feedback_card.dart';

/// Shared by the parent's child dashboard and the child's feedback screen.
class ProgressPanel extends ConsumerWidget {
  const ProgressPanel({
    super.key,
    required this.childId,
    this.childFriendly = false,
  });

  final String childId;
  final bool childFriendly;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(familyProgressProvider(childId))
      .when(
        loading: () => const Column(
          children: [
            Skeleton(height: AppSizes.childTile),
            SizedBox(height: AppSpacing.md),
            Skeleton(height: AppSizes.childTile),
          ],
        ),
        error: (error, _) => EmptyState(
          icon: LucideIcons.triangleAlert,
          title: context.l10n.errorTitle,
          message: error is AppFailure
              ? context.l10n.failureMessage(error)
              : context.l10n.errorMessage,
          actionLabel: ProgressStrings.retry,
          onAction: () => ref.invalidate(familyProgressProvider(childId)),
        ),
        data: (progress) => _ProgressContent(
          key: ValueKey(childId),
          progress: progress,
          childFriendly: childFriendly,
        ),
      );
}

class ParentProgressPanel extends StatelessWidget {
  const ParentProgressPanel({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) => ProgressPanel(childId: childId);
}

class _ProgressContent extends ConsumerStatefulWidget {
  const _ProgressContent({
    super.key,
    required this.progress,
    required this.childFriendly,
  });

  final FamilyProgress progress;
  final bool childFriendly;

  @override
  ConsumerState<_ProgressContent> createState() => _ProgressContentState();
}

class _ProgressContentState extends ConsumerState<_ProgressContent> {
  WordAudioController? _audio;
  String? _playingId;
  String? _loadingId;

  @override
  void dispose() {
    _audio?.dispose();
    super.dispose();
  }

  Future<void> _listen(TherapistFeedback feedback) async {
    if (_loadingId != null) return;
    if (_playingId == feedback.id) {
      await _audio?.stopPlayback();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    setState(() => _loadingId = feedback.id);
    await runWithFailureMessage(context, () async {
      final bytes = await ref
          .read(familyProgressRepositoryProvider)
          .feedbackAudio(widget.progress.patientId, feedback);
      if (!mounted) return;
      final player = _audio ??= WordAudioController();
      await player.play(bytes);
      if (mounted) setState(() => _playingId = feedback.id);
    });
    if (mounted) setState(() => _loadingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final summary = ProgressSummary(progress: progress);
    final feedback = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(ProgressStrings.feedback),
        if (progress.feedback.isEmpty)
          const EmptyState(
            icon: LucideIcons.messageCircle,
            title: ProgressStrings.noFeedbackTitle,
            message: ProgressStrings.noFeedbackBody,
          ),
        for (final item in progress.feedback) ...[
          TherapistFeedbackCard(
            feedback: item,
            audioLoading: _loadingId == item.id,
            playing: _playingId == item.id,
            onListen: _loadingId == null ? () => _listen(item) : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_audio?.message case final String message)
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.childFriendly) ...[
          Text(ProgressStrings.childIntro),
          const SizedBox(height: AppSpacing.lg),
          feedback,
          const SizedBox(height: AppSpacing.lg),
          summary,
        ] else ...[
          summary,
          const SizedBox(height: AppSpacing.lg),
          feedback,
        ],
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          label: ProgressStrings.refresh,
          icon: LucideIcons.refreshCw,
          onPressed: () =>
              ref.invalidate(familyProgressProvider(progress.patientId)),
        ),
      ],
    );
  }
}
