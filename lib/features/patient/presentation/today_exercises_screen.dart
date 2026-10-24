import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/celebration.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/entry_cascade.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import 'child_activity_picture.dart';
import 'child_practice_intro.dart';
import 'exercise_practice_card.dart';
import 'practice_day_summary.dart';

class TodayExercisesScreen extends ConsumerWidget {
  const TodayExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final activity = ref.watch(patientActivityProvider(user.id));
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Text(l10n.exercisesTitle),
      ),
      body: AsyncView(
        value: activity,
        data: (activity) {
          final items = activity.todayItems;
          if (items.isEmpty) {
            return PageList(
              children: [
                EmptyState(
                  icon: LucideIcons.calendarCheck,
                  title: l10n.exercisesNoneTitle,
                  message: l10n.exercisesNoneBody,
                ),
              ],
            );
          }
          final next = items.where((item) => !item.isDone).firstOrNull;
          return PageList(
            children: [
              ChildPracticeIntro(
                activity: ChildActivity.activities,
                message: l10n.childActivitiesIntro,
                color: AppColors.childButter,
              ),
              const SizedBox(height: AppSpacing.lg),
              PracticeDaySummary(activity: activity),
              const SizedBox(height: AppSpacing.xl),
              EntryCascade(
                children: [
                  for (final (index, item) in items.indexed)
                    PracticeTimelineEntry(
                      key: ValueKey(item.schedule.id),
                      number: index + 1,
                      done: item.isDone,
                      featured: identical(item, next),
                      previousDone: index > 0 && items[index - 1].isDone,
                      isFirst: index == 0,
                      isLast: index == items.length - 1,
                      child: ExercisePracticeCard(
                        item: item,
                        featured: identical(item, next),
                        onOpen: () => context.go(
                          AppRoutes.patientExercise(item.exercise.id),
                        ),
                        onSession: (done) async {
                          // A diary session is completed by its entry, so
                          // marking it opens the diary instead.
                          if (done &&
                              item.exercise.verificationType ==
                                  VerificationType.voiceDiary) {
                            unawaited(
                              context.push(
                                AppRoutes.patientVoiceDiary(item.exercise.id),
                              ),
                            );
                            return;
                          }
                          final actions = ref.read(completionActionsProvider);
                          final saved = await runWithFailureMessage(
                            context,
                            () => done
                                ? actions.addSession(user.id, item)
                                : actions.removeSession(user.id, item),
                          );
                          final finished =
                              item.sessionsDone + 1 >=
                              item.schedule.sessionsPerDay;
                          if (saved && done && finished && context.mounted) {
                            await showCelebration(
                              context,
                              message: l10n.childGameDone(item.exercise.title),
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "5 min  ·  10 reps  ·  twice a day" in the monospace face used for
/// technical values.
class ExerciseMeta extends StatelessWidget {
  const ExerciseMeta({
    super.key,
    required this.minutes,
    required this.repetitions,
    required this.sessions,
  });

  final int minutes;
  final int repetitions;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.exerciseDosage(minutes, repetitions, sessions),
      style: AppTypography.monoSmall.copyWith(color: AppColors.muted),
    );
  }
}
