import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/stat_tile.dart';
import '../../therapist/presentation/controllers/caseload_controllers.dart';
import '../../therapist/presentation/participant_detail_screen.dart';
import '../domain/usage_event.dart';
import 'controllers/usage_controllers.dart';

/// A caseload participant's Application Usage Log.
class UsageLogScreen extends ConsumerWidget {
  const UsageLogScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participant = ref.watch(caseloadParticipantProvider(patientId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.usageLogTitle)),
      body: AsyncView(
        value: participant,
        data: (participant) => participant == null
            ? const ParticipantNotFound()
            : _UsageLogBody(patientId: patientId, code: participant.code),
      ),
    );
  }
}

class _UsageLogBody extends ConsumerWidget {
  const _UsageLogBody({required this.patientId, required this.code});

  final String patientId;
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final events = ref.watch(usageLogProvider(patientId));
    return AsyncView(
      value: events,
      data: (events) {
        if (events.isEmpty) {
          return EmptyState(
            icon: LucideIcons.activity,
            title: l10n.usageEmptyTitle,
            message: l10n.usageEmptyBody,
          );
        }
        final activeDays = {for (final e in events) dateOnly(e.at)}.length;
        return PageList(
          children: [
            Text(code, style: AppTypography.participantCode),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: StatTile(
                    icon: LucideIcons.calendarDays,
                    label: l10n.usageActiveDays,
                    value: '$activeDays',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 6,
                  child: StatTile(
                    icon: LucideIcons.clock,
                    label: l10n.usageLastUsed,
                    value: formatShortDate(events.first.at),
                    caption: formatClock(events.first.at),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.usageEventsSection(events.length)),
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _EventRow(event: event),
              ),
          ],
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final UsageEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return InkCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.usageLabel(event.action), style: text.bodyLarge),
                if (event.detail.isNotEmpty)
                  Text(event.detail, style: AppTypography.monoSmall),
              ],
            ),
          ),
          Text(formatDateTime(event.at), style: text.bodySmall),
        ],
      ),
    );
  }
}
