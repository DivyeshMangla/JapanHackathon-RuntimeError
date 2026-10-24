import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/seal_mark.dart';
import 'setup_actions.dart';
import 'transfer_buttons.dart';

const _orientationSteps = 3;
const _baselineTasks = 3;

class AwaitingPlanPage extends ConsumerStatefulWidget {
  const AwaitingPlanPage({super.key});

  @override
  ConsumerState<AwaitingPlanPage> createState() => _AwaitingPlanPageState();
}

class _AwaitingPlanPageState extends ConsumerState<AwaitingPlanPage>
    with SetupActions {
  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('awaitingPlan'),
      error: error,
      actions: [
        TransferButtons(
          sending: false,
          qrLabel: label('scanQr'),
          fileLabel: label('importFile'),
          onQr: action(
            'scanQr',
            () => receive(qr: true, accept: service.importPlan),
          ),
          onFile: action(
            'importFile',
            () => receive(qr: false, accept: service.importPlan),
          ),
        ),
      ],
      children: [
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const SealMark(icon: LucideIcons.hourglass),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(s('waitingHelp'))),
            ],
          ),
        ),
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s('resendConsent'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TransferButtons(
                sending: true,
                emphasised: false,
                qrLabel: label('showQr'),
                fileLabel: label('exportFile'),
                onQr: action(
                  'showQr',
                  () => send(qr: true, envelope: service.consentEnvelope),
                ),
                onFile: action(
                  'exportFile',
                  () => send(qr: false, envelope: service.consentEnvelope),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OrientationPage extends ConsumerStatefulWidget {
  const OrientationPage({super.key});

  @override
  ConsumerState<OrientationPage> createState() => _OrientationPageState();
}

class _OrientationPageState extends ConsumerState<OrientationPage>
    with SetupActions {
  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('orientation'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('continue'),
          onPressed: action('continue', service.finishOrientation),
        ),
      ],
      children: [
        for (var step = 1; step <= _orientationSteps; step++)
          InkCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              s('orientation$step'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
      ],
    );
  }
}

class BaselinePage extends ConsumerStatefulWidget {
  const BaselinePage({super.key});

  @override
  ConsumerState<BaselinePage> createState() => _BaselinePageState();
}

class _BaselinePageState extends ConsumerState<BaselinePage> with SetupActions {
  @override
  Widget build(BuildContext context) {
    final done = service.baselineDone;
    return ActionPage(
      title: s('baseline'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('continue'),
          onPressed: action(
            'continue',
            service.finishBaseline,
            enabled: done.length == _baselineTasks,
          ),
        ),
      ],
      children: [
        PlaceholderNotice(s('baselineStub')),
        for (var task = 0; task < _baselineTasks; task++)
          _BaselineTask(
            title: s('baseline${task + 1}'),
            done: done.contains(task),
            recordLabel: s('recordStub'),
            onRecord: action(
              'baseline$task',
              () => service.completeBaseline(task),
            ),
          ),
      ],
    );
  }
}

class _BaselineTask extends StatelessWidget {
  const _BaselineTask({
    required this.title,
    required this.done,
    required this.recordLabel,
    required this.onRecord,
  });

  final String title;
  final bool done;
  final String recordLabel;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (done)
            const SizedBox.square(
              dimension: AppSizes.minTouchTarget,
              child: Icon(LucideIcons.circleCheck, color: AppColors.ink),
            )
          else
            IconButton(
              tooltip: recordLabel,
              onPressed: onRecord,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.surface,
              ),
              icon: const Icon(LucideIcons.mic, size: 20),
            ),
        ],
      ),
    );
  }
}

class SetupCompletePage extends ConsumerStatefulWidget {
  const SetupCompletePage({super.key});

  @override
  ConsumerState<SetupCompletePage> createState() => _SetupCompletePageState();
}

class _SetupCompletePageState extends ConsumerState<SetupCompletePage>
    with SetupActions {
  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('active'),
      children: [
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const SealMark(icon: LucideIcons.circleCheck),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(s('todayStub'))),
            ],
          ),
        ),
      ],
    );
  }
}
