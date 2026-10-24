import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../domain/access_log.dart';
import 'controllers/access_log_controllers.dart';

/// Read-only view of the append-only access log, newest first.
class AccessLogScreen extends ConsumerWidget {
  const AccessLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final log = ref.watch(accessLogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accessLogTitle)),
      body: AsyncView(
        value: log,
        data: (entries) => entries.isEmpty
            ? EmptyState(
                icon: LucideIcons.scrollText,
                title: l10n.accessLogEmptyTitle,
                message: l10n.accessLogEmptyBody,
              )
            : PageList(
                children: [
                  Text(
                    l10n.accessLogShowing(entries.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _EntryCard(entry: entry),
                    ),
                ],
              ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final AccessLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            entry.action == AccessAction.export
                ? LucideIcons.fileDown
                : LucideIcons.headphones,
            size: 18,
            color: AppColors.seal,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.accessActionLabel(entry.action),
                  style: text.titleSmall,
                ),
                Text(entry.target, style: text.bodyMedium),
                Text(entry.userEmail, style: text.bodySmall),
                Text(
                  formatDateTime(entry.at),
                  style: AppTypography.monoSmall.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
