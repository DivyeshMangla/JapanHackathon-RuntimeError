import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/l10n.dart';
import 'ink_card.dart';

/// A code someone else types to join this account: a therapist's code for
/// parents, a parent's code for their child's device.
class LinkCodeCard extends StatelessWidget {
  const LinkCodeCard({
    super.key,
    required this.title,
    required this.code,
    required this.message,
  });

  final String title;
  final String code;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: AppTypography.monoHeadline.copyWith(
                    letterSpacing: AppSpacing.xs,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.codeCopy,
                icon: const Icon(LucideIcons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.codeCopied)));
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: text.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
