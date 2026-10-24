import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../motor/domain/motor.dart';
import '../../motor/presentation/controllers/motor_controllers.dart';
import 'controllers/family_controllers.dart';
import 'start_child_mode_button.dart';

/// One child as their parent sees them: the way into child mode, the
/// consent signed when they were added and the therapist's drawing
/// feedback.
class ChildDetailScreen extends ConsumerWidget {
  const ChildDetailScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final child = ref.watch(familyChildProvider(childId));
    return Scaffold(
      appBar: AppBar(title: Text(child.value?.name ?? '')),
      body: AsyncView(
        value: child,
        data: (child) => child == null
            ? PageList(
                children: [
                  EmptyState(
                    icon: LucideIcons.userX,
                    title: l10n.parentChildNotFoundTitle,
                    message: l10n.parentChildNotFoundBody,
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(childConsentProvider(childId))
                    ..invalidate(motorRecordProvider(childId));
                },
                child: PageList(
                  children: [
                    StartChildModeButton(child: child, primary: true),
                    const SizedBox(height: AppSpacing.lg),
                    _ConsentOnFile(childId: childId),
                    const SizedBox(height: AppSpacing.xl),
                    SectionLabel(l10n.parentDrawingFeedback),
                    _DrawingFeedback(childId: childId),
                  ],
                ),
              ),
      ),
    );
  }
}

/// The consent the parent signed when adding the child. It is never asked
/// for again, so this only reports it.
class _ConsentOnFile extends ConsumerWidget {
  const _ConsentOnFile({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AsyncView(
      value: ref.watch(childConsentProvider(childId)),
      loading: const Skeleton(height: AppSizes.minTouchTarget),
      data: (consent) => InkCard(
        child: Row(
          children: [
            Icon(
              consent == null
                  ? LucideIcons.circleAlert
                  : LucideIcons.circleCheck,
              color: consent == null ? AppColors.ink : AppColors.teal,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                consent == null
                    ? l10n.parentConsentMissing
                    : l10n.parentConsentSigned(
                        formatShortDate(consent.signedAt),
                      ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingFeedback extends ConsumerWidget {
  const _DrawingFeedback({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final names = {
      for (final exercise
          in ref.watch(motorExercisesProvider).value ?? const <MotorExercise>[])
        exercise.id: exercise.name,
    };
    return AsyncView(
      value: ref.watch(motorRecordProvider(childId)),
      loading: const Skeleton(height: AppSizes.childTile),
      data: (record) {
        final reviewed = [
          for (final submission in record.submissions)
            if (submission.reviewNote != null) submission,
        ];
        if (reviewed.isEmpty) return Text(l10n.parentNoDrawingFeedback);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final submission in reviewed.take(5)) ...[
              InkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${names[submission.exerciseId] ?? submission.exerciseId} · ${submission.practiceDay}',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(submission.reviewNote!),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}
