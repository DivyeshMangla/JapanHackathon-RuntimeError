import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/entry_cascade.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/melo_mark.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import '../../motor/presentation/controllers/motor_controllers.dart';
import 'child_activity_picture.dart';
import 'child_tile.dart';

/// The child's home: a friendly hello, today's stars and three big picture
/// buttons. Words are kept short so a grown-up can read along.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentUserProvider);
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(patientActivityProvider(child.id)).value;
    final done = today?.todayAdherence.done ?? 0;
    final due = today?.todayAdherence.due ?? 0;
    final drawing = ref.watch(motorRecordProvider(child.id)).value;
    final drawingsDone =
        drawing?.doneOn(DateFormat('yyyy-MM-dd').format(DateTime.now())) ??
        const {};
    final drawingsDue = drawing?.exerciseIds.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(patientActivityProvider(child.id))
              ..invalidate(motorRecordProvider(child.id));
          },
          child: PageList(
            children: [
              EntryCascade(
                children: [
                  Row(
                    children: [
                      const MeloMark(size: AppSizes.childMascot),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.base),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.childHello(child.firstName),
                                style: text.headlineLarge,
                              ),
                              Text(
                                l10n.childPrompt,
                                style: text.bodyLarge?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (due > 0) ...[
                    _StarRow(done: done, due: due),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  ChildTile(
                    picture: ChildActivity.activities,
                    icon: LucideIcons.puzzle,
                    color: AppColors.childButter,
                    title: l10n.childGames,
                    subtitle: due == 0
                        ? l10n.childGamesNone
                        : l10n.childGamesProgress(done, due),
                    done: due > 0 && done >= due,
                    onTap: () => context.push(AppRoutes.patientExercises),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ChildTile(
                    picture: ChildActivity.words,
                    icon: LucideIcons.messageCircle,
                    color: AppColors.childMint,
                    title: l10n.childWords,
                    subtitle: l10n.childWordsHint,
                    onTap: () => context.push(AppRoutes.patientWords),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ChildTile(
                    picture: ChildActivity.drawing,
                    icon: LucideIcons.pencil,
                    color: AppColors.childRose,
                    title: l10n.childDrawing,
                    subtitle: drawingsDue == 0
                        ? l10n.childDrawingHint
                        : l10n.childGamesProgress(
                            drawingsDone.length,
                            drawingsDue,
                          ),
                    done: drawingsDue > 0 && drawingsDone.length >= drawingsDue,
                    onTap: () => context.push(AppRoutes.patientDrawing),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _GrownUpsButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One star per practice game due today, filled as each is done.
class _StarRow extends StatelessWidget {
  const _StarRow({required this.done, required this.due});

  final int done;
  final int due;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.childStars(done, due),
      excludeSemantics: true,
      child: InkCard(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < due; i++)
              Icon(
                i < done ? Icons.star_rounded : Icons.star_outline_rounded,
                size: AppSizes.minTouchTarget,
                color: i < done ? AppColors.sunshine : AppColors.hairline,
              ),
          ],
        ),
      ),
    );
  }
}

/// Signing out is for a grown-up handing the device to someone else, so it
/// sits at the bottom and asks first.
class _GrownUpsButton extends ConsumerWidget {
  const _GrownUpsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Center(
      child: TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: AppColors.muted),
        icon: const Icon(LucideIcons.logOut),
        label: Text(l10n.childGrownUps),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: Text(l10n.childSignOutTitle),
              content: Text(l10n.childSignOutBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: Text(l10n.signOut),
                ),
              ],
            ),
          );
          if (confirmed != true || !context.mounted) return;
          await runWithFailureMessage(
            context,
            () => ref.read(authControllerProvider.notifier).signOut(),
          );
        },
      ),
    );
  }
}
