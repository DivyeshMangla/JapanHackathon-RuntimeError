import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import '../../motor/domain/motor.dart';
import '../../motor/presentation/controllers/motor_controllers.dart';
import 'child_progress.dart';
import 'consent_status.dart';
import 'controllers/family_controllers.dart';

/// One child as their parent sees them: consent, today's practice, how the
/// last weeks went and the therapist's drawing feedback.
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
                    ..invalidate(patientActivityProvider(childId))
                    ..invalidate(childConsentProvider(childId))
                    ..invalidate(motorRecordProvider(childId));
                },
                child: PageList(
                  children: [
                    InkCard(child: ConsentStatus(childId: childId)),
                    const SizedBox(height: AppSpacing.xl),
                    SectionLabel(l10n.parentToday),
                    _TodayPractice(childId: childId),
                    const SizedBox(height: AppSpacing.xl),
                    SectionLabel(l10n.parentProgress),
                    ChildProgress(userId: childId),
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

class _TodayPractice extends ConsumerWidget {
  const _TodayPractice({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AsyncView(
      value: ref.watch(patientActivityProvider(childId)),
      loading: const Skeleton(height: AppSizes.childTile),
      data: (activity) {
        final items = activity.todayItems;
        if (items.isEmpty) return Text(l10n.parentNothingToday);
        return InkCard(
          child: Column(
            children: [
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.isDone ? LucideIcons.circleCheck : LucideIcons.circle,
                    color: item.isDone ? AppColors.teal : AppColors.wash,
                  ),
                  title: Text(item.exercise.title),
                  subtitle: Text(
                    item.isDone ? l10n.parentGameDone : l10n.parentGameToDo,
                  ),
                ),
            ],
          ),
        );
      },
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
