import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/seal_mark.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../capture_quality/domain/take_quality.dart';
import '../../recordings/domain/probe_protocol.dart';
import '../../recordings/domain/recording.dart';
import '../../recordings/presentation/controllers/playback_controller.dart';
import '../../recordings/presentation/controllers/recording_controllers.dart';
import '../../recordings/presentation/controllers/recording_session.dart';
import '../../recordings/presentation/live_input_trace.dart';
import '../../recordings/presentation/playback_button.dart';
import '../../recordings/presentation/take_quality_card.dart';

class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(recordingSessionProvider);
    final l10n = context.l10n;

    ref.listen(recordingSessionProvider.select((s) => s.failure), (_, failure) {
      if (failure != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failureMessage(failure))));
      }
    });
    ref.listen(recordingSessionProvider.select((s) => s.microphoneDenied), (
      _,
      denied,
    ) {
      if (denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.recordMicOff)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          !session.isProbe || session.stage == RecordingStage.setup
              ? l10n.recordTitle
              : session.type == RecordingType.baseline
              ? l10n.recordBaselineTitle
              : l10n.recordProbeTitle,
        ),
      ),
      body: PageList(
        children: [
          switch (session.stage) {
            RecordingStage.setup => _Setup(session: session),
            RecordingStage.ready => _ProbeReady(session: session),
            RecordingStage.recording => _Recording(session: session),
            RecordingStage.review ||
            RecordingStage.saving => _Review(session: session),
            RecordingStage.probeComplete => const _ProbeComplete(),
          },
        ],
      ),
    );
  }
}

class _Setup extends ConsumerWidget {
  const _Setup({required this.session});

  final RecordingSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final controller = ref.read(recordingSessionProvider.notifier);
    final user = ref.watch(currentUserProvider);
    final probe = ref.watch(probeDueProvider(user.id)).value;
    final due = probe?.isDueOn(DateTime.now()) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (due) ...[const _ProbeCard(), const SizedBox(height: AppSpacing.lg)],
        SectionLabel(l10n.recordPracticeTitle),
        Text(l10n.recordPracticeBody, style: text.bodySmall),
        const SizedBox(height: AppSpacing.md),
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SealMark(size: 64, icon: LucideIcons.mic)),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.taskLabel(session.practiceTask),
                style: text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.taskInstructions(session.practiceTask),
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: due ? AppColors.ink : AppColors.sunshine,
                  foregroundColor: due ? AppColors.surface : AppColors.ink,
                ),
                label: Text(l10n.recordStart),
                icon: const Icon(LucideIcons.mic, size: 18),
                onPressed: controller.startPractice,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final task in RecordingTask.practiceTasks)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _TaskOption(
              task: task,
              selected: task == session.practiceTask,
              onTap: () => controller.selectPracticeTask(task),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.recordTip, style: text.bodySmall),
        if (!due) ...[
          const SizedBox(height: AppSpacing.lg),
          const _ProbeCard(),
        ],
      ],
    );
  }
}

/// Entry point for the probe protocol, with where the patient is in the
/// probe schedule.
class _ProbeCard extends ConsumerWidget {
  const _ProbeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider);
    final probe = ref.watch(probeDueProvider(user.id)).value;
    final baseline = probe?.isBaseline ?? true;
    final next = probe?.nextDue;
    final status = probe == null || probe.isDueOn(DateTime.now())
        ? l10n.recordProbeDueNow
        : next != null
        ? l10n.recordProbeNext(formatDayMonth(next))
        : l10n.recordProbeFinished;

    final due = probe?.isDueOn(DateTime.now()) ?? false;
    return InkCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: AppSpacing.md),
        initiallyExpanded: due,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(LucideIcons.audioLines, size: 22),
        title: Text(
          baseline ? l10n.recordBaselineTitle : l10n.recordProbeTitle,
          style: text.titleMedium,
        ),
        subtitle: Text(status, style: text.bodySmall),
        children: [
          Text(
            l10n.recordProbeBody(ProbeProtocol.takes.length),
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l10n.recordProbeStart,
            icon: LucideIcons.arrowRight,
            onPressed: () => ref
                .read(recordingSessionProvider.notifier)
                .beginProbe(baseline: baseline),
          ),
        ],
      ),
    );
  }
}

class _TaskOption extends StatelessWidget {
  const _TaskOption({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final RecordingTask task;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    RecordingTask.sustainedPhonation: LucideIcons.audioLines,
    RecordingTask.readingPassage: LucideIcons.bookOpen,
    RecordingTask.spontaneousSpeech: LucideIcons.messageCircle,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Semantics(
      selected: selected,
      child: InkCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _icons[task],
              color: selected ? AppColors.seal : AppColors.wash,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.taskLabel(task),
                    style: text.titleMedium?.copyWith(
                      color: selected ? AppColors.seal : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected ? LucideIcons.circleCheck : LucideIcons.circle,
              color: selected ? AppColors.seal : AppColors.hairline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress through the probe protocol plus the current task's instructions.
class _ProbeHeading extends StatelessWidget {
  const _ProbeHeading({required this.session});

  final RecordingSessionState session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final take = session.probeTake;
    final total = ProbeProtocol.takes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.recordTakeOf(session.probeIndex + 1, total),
          style: text.labelMedium?.copyWith(color: AppColors.seal),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.base),
          child: LinearProgressIndicator(
            value: session.probeIndex / total,
            minHeight: AppSizes.progressThin,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.taskLabel(take.task), style: text.headlineMedium),
        if (take.of > 1)
          Text(l10n.recordTrialOf(take.trial, take.of), style: text.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        _TaskInstructions(task: take.task),
      ],
    );
  }
}

class _TaskInstructions extends StatelessWidget {
  const _TaskInstructions({required this.task});

  final RecordingTask task;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.taskInstructions(task),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (task == RecordingTask.readingPassage) ...[
          const SizedBox(height: AppSpacing.md),
          InkCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l10n.readingPassage, style: AppTypography.body),
          ),
        ],
      ],
    );
  }
}

class _ProbeReady extends ConsumerWidget {
  const _ProbeReady({required this.session});

  final RecordingSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(recordingSessionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProbeHeading(session: session),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: l10n.recordBegin,
          icon: LucideIcons.mic,
          onPressed: controller.start,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: controller.finishLater,
          child: Text(l10n.recordFinishLater),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.recordTip, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Recording extends ConsumerWidget {
  const _Recording({required this.session});

  final RecordingSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.isProbe)
          _ProbeHeading(session: session)
        else ...[
          Text(
            l10n.taskLabel(session.task),
            style: text.labelMedium?.copyWith(color: AppColors.seal),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TaskInstructions(task: session.task),
        ],
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: AppColors.darkGradient,
            borderRadius: BorderRadius.circular(AppRadius.base),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: AppSpacing.sm,
                    height: AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: session.leadInDone
                          ? AppColors.sunshine
                          : AppColors.onDarkMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      session.leadInDone ? l10n.recordGo : l10n.recordWait,
                      style: text.labelMedium?.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                formatSeconds(session.elapsedSec),
                textAlign: TextAlign.center,
                style: AppTypography.recordTimer.copyWith(
                  color: AppColors.surface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LiveInputTrace(level: session.level),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.recordInputLevel,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.onDarkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.ink,
                ),
                label: Text(l10n.recordStop),
                icon: const Icon(LucideIcons.square, size: 18),
                onPressed: ref.read(recordingSessionProvider.notifier).stop,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.recordAutoStop(RecordingSession.maxLength.inMinutes),
          style: text.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Review extends ConsumerWidget {
  const _Review({required this.session});

  final RecordingSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final controller = ref.read(recordingSessionProvider.notifier);
    final saving = session.stage == RecordingStage.saving;
    // A take that failed the quality check makes recording again the main
    // action, but the patient can still keep it.
    final poor = session.quality?.rating == TakeRating.poor;
    final saveLabel = saving
        ? l10n.recordSaving
        : poor
        ? l10n.recordKeepAnyway
        : session.isProbe
        ? l10n.recordSaveNext
        : l10n.recordSave;

    Future<void> save() async {
      await controller.save(ref.read(currentUserProvider));
      if (context.mounted && !session.isProbe) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.recordSaved)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.isProbe) ...[
          _ProbeHeading(session: session),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(l10n.recordListenBack, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.recordReviewBody, style: text.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        InkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.taskLabel(session.task), style: text.titleMedium),
              Text(l10n.typeLabel(session.type), style: text.bodySmall),
              const SizedBox(height: AppSpacing.md),
              if (session.draftPath case final path?)
                PlaybackButton(
                  source: PlaybackSource.draft(path),
                  durationSec: session.elapsedSec,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TakeQualityCard(
          quality: session.quality,
          checking: session.checkingQuality,
        ),
        const SizedBox(height: AppSpacing.xl),
        if (poor) ...[
          PrimaryButton(
            label: l10n.recordAgain,
            icon: LucideIcons.rotateCcw,
            onPressed: saving ? null : controller.retake,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: saveLabel,
            icon: LucideIcons.check,
            onPressed: saving ? null : save,
          ),
        ] else ...[
          PrimaryButton(
            label: saveLabel,
            icon: LucideIcons.check,
            onPressed: saving ? null : save,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: l10n.recordAgain,
            icon: LucideIcons.rotateCcw,
            onPressed: saving ? null : controller.retake,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: saving ? null : controller.discard,
          child: Text(
            session.isProbe ? l10n.recordFinishLater : l10n.recordDiscard,
          ),
        ),
      ],
    );
  }
}

class _ProbeComplete extends ConsumerWidget {
  const _ProbeComplete();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const SealMark(size: 64, icon: LucideIcons.check),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.recordCompleteTitle, style: text.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.recordCompleteBody, style: text.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: l10n.recordDone,
          icon: LucideIcons.arrowRight,
          onPressed: ref.read(recordingSessionProvider.notifier).finishLater,
        ),
      ],
    );
  }
}
