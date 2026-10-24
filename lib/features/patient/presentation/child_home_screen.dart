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
import '../../../shared/widgets/melo_mark.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../motor/presentation/controllers/motor_controllers.dart';
import 'child_activity_picture.dart';
import 'child_tile.dart';
import 'leave_child_mode_dialog.dart';

/// The child's home in child mode: a friendly hello and big picture
/// buttons. Words are kept short so a grown-up can read along.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentUserProvider);
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final drawing = ref.watch(motorRecordProvider(child.id)).value;
    final drawingsDone =
        drawing?.doneOn(DateFormat('yyyy-MM-dd').format(DateTime.now())) ??
        const {};
    final drawingsDue = drawing?.exerciseIds.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(motorRecordProvider(child.id)),
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
                  ChildTile(
                    picture: ChildActivity.expressions,
                    icon: LucideIcons.smile,
                    color: AppColors.childButter,
                    title: l10n.childExpressions,
                    subtitle: l10n.childExpressionsHint,
                    onTap: () => context.push(AppRoutes.patientExpressions),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ChildTile(
                    icon: LucideIcons.messageSquare,
                    color: AppColors.surface,
                    title: l10n.childProgress,
                    subtitle: l10n.childProgressHint,
                    onTap: () => context.push(AppRoutes.patientProgress),
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

/// Leaving child mode is for a grown-up, so it sits at the bottom and asks
/// for the parent's PIN.
class _GrownUpsButton extends StatelessWidget {
  const _GrownUpsButton();

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: AppColors.muted),
      icon: const Icon(LucideIcons.lockKeyhole),
      label: Text(context.l10n.childGrownUps),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const LeaveChildModeDialog(),
      ),
    ),
  );
}
