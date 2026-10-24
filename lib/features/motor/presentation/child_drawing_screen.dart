import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../patient/presentation/child_activity_picture.dart';
import '../../patient/presentation/child_practice_intro.dart';
import '../../patient/presentation/child_tile.dart';
import 'controllers/motor_controllers.dart';

/// The drawing tasks the child's therapist picked, each ticked once a photo
/// of today's attempt has been sent.
class ChildDrawingScreen extends ConsumerWidget {
  const ChildDrawingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentUserProvider);
    final l10n = context.l10n;
    final catalogue = ref.watch(motorExercisesProvider);
    final record = ref.watch(motorRecordProvider(child.id));
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    const colors = [
      AppColors.childRose,
      AppColors.childButter,
      AppColors.childMint,
    ];
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        title: Text(l10n.drawingTitle),
      ),
      body: AsyncView(
        value: catalogue,
        data: (catalogue) => AsyncView(
          value: record,
          data: (record) {
            final planned = record.plannedFrom(catalogue);
            if (!record.consented) {
              return PageList(
                children: [
                  EmptyState(
                    icon: LucideIcons.penLine,
                    title: l10n.drawingWaitingTitle,
                    message: l10n.drawingNeedsConsent,
                  ),
                ],
              );
            }
            if (planned.isEmpty) {
              return PageList(
                children: [
                  EmptyState(
                    icon: LucideIcons.pencil,
                    title: l10n.drawingWaitingTitle,
                    message: l10n.drawingNothingYet,
                  ),
                ],
              );
            }
            final done = record.doneOn(today);
            return PageList(
              children: [
                ChildPracticeIntro(
                  activity: ChildActivity.drawing,
                  message: l10n.childDrawingIntro,
                  color: AppColors.childRose,
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final (index, exercise) in planned.indexed) ...[
                  ChildTile(
                    picture: ChildActivity.drawing,
                    icon: LucideIcons.pencil,
                    color: colors[index % colors.length],
                    title: exercise.name,
                    subtitle: done.contains(exercise.id)
                        ? l10n.drawingDoneToday
                        : exercise.description,
                    done: done.contains(exercise.id),
                    onTap: () => context.push(
                      AppRoutes.patientDrawingExercise(exercise.id),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  l10n.motorDailyGuidance,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
