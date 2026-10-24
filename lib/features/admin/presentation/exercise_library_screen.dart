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
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  ExerciseStatus? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final library = ref.watch(exerciseLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTitle)),
      body: AsyncView(
        value: library,
        data: (library) {
          final shown = [
            for (final e in library)
              if (_status == null || e.status == _status) e,
          ];
          return PageList(
            children: [
              ChoicePills<ExerciseStatus?>(
                options: const [null, ...ExerciseStatus.values],
                selected: _status,
                labelOf: (s) => s == null
                    ? l10n.filterAllCount(library.length)
                    : l10n.statusCount(
                        l10n.exerciseStatusLabel(s),
                        library.where((e) => e.status == s).length,
                      ),
                onSelected: (s) => setState(() => _status = s),
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.newExercise,
                icon: LucideIcons.plus,
                onPressed: () => context.go(AppRoutes.adminNewExercise),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (shown.isEmpty)
                EmptyState(
                  icon: LucideIcons.libraryBig,
                  title: l10n.noExercisesTitle,
                  message: l10n.noExercisesBody,
                ),
              for (final (program, members) in groupByProgram(shown)) ...[
                SectionLabel(program),
                for (final exercise in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ExerciseRow(exercise: exercise),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkCard(
      onTap: () => context.go(AppRoutes.adminExercise(exercise.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.title, style: text.titleMedium),
                Text(exercise.summary, style: text.bodySmall, maxLines: 2),
              ],
            ),
          ),
          ExerciseStatusChip(status: exercise.status),
        ],
      ),
    );
  }
}

/// Status with an icon and label, never colour alone.
class ExerciseStatusChip extends StatelessWidget {
  const ExerciseStatusChip({super.key, required this.status});

  final ExerciseStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      ExerciseStatus.approved => (LucideIcons.badgeCheck, AppColors.ink),
      ExerciseStatus.pendingApproval => (LucideIcons.clock, AppColors.seal),
      ExerciseStatus.archived => (LucideIcons.archive, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            context.l10n.exerciseStatusLabel(status),
            style: AppTypography.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
