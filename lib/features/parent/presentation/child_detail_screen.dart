import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../progress/presentation/controllers/progress_controllers.dart';
import '../../progress/presentation/progress_panel.dart';
import '../../progress/presentation/progress_strings.dart';
import 'controllers/family_controllers.dart';
import 'controllers/hosted_analysis_controllers.dart';
import 'parent_hosted_analysis_panel.dart';
import 'start_child_mode_button.dart';

/// One child as their parent sees them: the way into child mode, the
/// consent signed when they were added, practice and therapist guidance.
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
                    ..invalidate(hostedAnalysisPermissionProvider(childId))
                    ..invalidate(familyProgressProvider(childId));
                  await runWithFailureMessage(context, () async {
                    await ref
                        .read(familyProgressProvider(childId).future)
                        .then<void>((_) {});
                  });
                },
                child: PageList(
                  children: [
                    StartChildModeButton(child: child, primary: true),
                    const SizedBox(height: AppSpacing.lg),
                    _ConsentOnFile(childId: childId),
                    const SizedBox(height: AppSpacing.lg),
                    ParentHostedAnalysisPanel(childId: childId),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionLabel(ProgressStrings.title),
                    ParentProgressPanel(childId: childId),
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
