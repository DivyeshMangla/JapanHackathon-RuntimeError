import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../data/connected_service.dart';
import 'account_page.dart';

/// Refresh, lock (therapists only) and account, at the top of both homes.
class HomeHeaderActions extends StatelessWidget {
  const HomeHeaderActions({super.key, required this.service});

  final ConnectedService service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.connectedRefresh,
          onPressed: service.syncing ? null : service.refresh,
          icon: const Icon(LucideIcons.refreshCw, size: 20),
        ),
        if (service.isTherapist) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: l10n.connectedLock,
            onPressed: service.lock,
            icon: const Icon(LucideIcons.lock, size: 20),
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: l10n.connectedAccount,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AccountPage(service: service),
            ),
          ),
          icon: const Icon(LucideIcons.userRound, size: 20),
        ),
      ],
    );
  }
}

/// Shown while practice saved on the phone is waiting to upload.
class OutboxCard extends StatelessWidget {
  const OutboxCard({super.key, required this.service});

  final ConnectedService service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.cloudUpload, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(l10n.connectedOutbox(service.outbox.length)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: service.syncing
                ? l10n.connectedSyncing
                : l10n.connectedSyncNow,
            icon: LucideIcons.refreshCw,
            onPressed: service.syncing ? null : service.sync,
          ),
        ],
      ),
    );
  }
}
