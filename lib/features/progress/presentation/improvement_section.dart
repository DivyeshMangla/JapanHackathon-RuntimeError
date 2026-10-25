import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/domain/user.dart';
import 'controllers/progress_controllers.dart';
import 'progress_strings.dart';
import 'progress_trend.dart';

/// The parent's first look at a child: one improvement graph per activity
/// the child has practised. Load errors are reported by the progress panel
/// further down the page, so this section simply stays out of the way.
class ImprovementSection extends ConsumerWidget {
  const ImprovementSection({super.key, required this.child});

  final User child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(familyProgressProvider(child.id))
      .when(
        loading: () => const Skeleton(height: AppSizes.trendChart),
        error: (_, _) => const SizedBox.shrink(),
        data: (progress) {
          final practised = progress.activities
              .where((activity) => activity.trend.isNotEmpty)
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(ProgressStrings.improvementTitle(child.name)),
              const Text(ProgressStrings.improvementHelp),
              const SizedBox(height: AppSpacing.md),
              if (practised.isEmpty)
                const EmptyState(
                  icon: LucideIcons.chartLine,
                  title: ProgressStrings.noImprovementTitle,
                  message: ProgressStrings.trendTooEarly,
                ),
              for (final activity in practised) ...[
                InkCard(child: ProgressTrend(progress: activity)),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      );
}
