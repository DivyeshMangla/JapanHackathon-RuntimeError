import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/entry_cascade.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/seal_mark.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import 'consent_status.dart';
import 'controllers/family_controllers.dart';

/// The parent's home: each child with today's practice and whether their
/// consent is signed.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = ref.watch(currentUserProvider);
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(familyChildrenProvider.future),
          child: PageList(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const SealMark(size: AppSizes.minTouchTarget),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.greeting(now, parent.firstName),
                          style: text.titleMedium,
                        ),
                        Text(formatLongDate(now), style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.parentHomeHeading, style: text.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              AsyncView(
                value: ref.watch(familyChildrenProvider),
                loading: const Skeleton(height: AppSizes.childTile),
                data: (children) => children.isEmpty
                    ? EmptyState(
                        icon: LucideIcons.smartphone,
                        title: l10n.parentNoChildrenTitle,
                        message: l10n.parentNoChildrenBody,
                        actionLabel: l10n.parentShowCode,
                        onAction: () => context.go(AppRoutes.parentSettings),
                      )
                    : EntryCascade(
                        children: [
                          for (final child in children) ...[
                            _ChildCard(child: child),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child});

  final User child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(patientActivityProvider(child.id)).value;
    final done = today?.todayAdherence.done ?? 0;
    final due = today?.todayAdherence.due ?? 0;
    return InkCard(
      onTap: () => context.push(AppRoutes.parentChild(child.id)),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChildAvatar(name: child.name),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(child.name, style: text.titleLarge)),
              const Icon(LucideIcons.chevronRight, color: AppColors.wash),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            due == 0
                ? l10n.parentNothingToday
                : l10n.parentTodayDone(done, due),
            style: text.bodyMedium,
          ),
          if (due > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: done / due,
                minHeight: AppSizes.progressThick,
                color: AppColors.sunshine,
                backgroundColor: AppColors.washTint,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ConsentStatus(childId: child.id),
        ],
      ),
    );
  }
}

/// The child's initial in a sunshine circle.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.minTouchTarget,
    height: AppSizes.minTouchTarget,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.sunshine,
      shape: BoxShape.circle,
    ),
    child: Text(
      name.isEmpty ? '' : name.characters.first.toUpperCase(),
      style: Theme.of(context).textTheme.titleLarge,
    ),
  );
}
