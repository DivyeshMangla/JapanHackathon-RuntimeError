import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../domain/participant_summary.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_card.dart';

class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({super.key});

  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  String _query = '';

  bool _matches(ParticipantSummary p) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty ||
        p.patient.name.toLowerCase().contains(q) ||
        p.code.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final caseload = ref.watch(caseloadProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.participantsTitle)),
      body: AsyncView(
        value: caseload,
        data: (caseload) {
          final results = caseload.where(_matches).toList();
          return PageList(
            children: [
              LabeledTextField(
                label: l10n.searchLabel,
                hint: l10n.searchHint,
                prefixIcon: LucideIcons.search,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (caseload.isEmpty)
                EmptyState(
                  icon: LucideIcons.users,
                  title: l10n.noParticipantsTitle,
                  message: l10n.noParticipantsBody,
                )
              else if (results.isEmpty)
                EmptyState(
                  icon: LucideIcons.searchX,
                  title: l10n.noMatchesTitle,
                  message: l10n.noMatchesBody(_query),
                )
              else
                for (final p in results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ParticipantCard(
                      participant: p,
                      onTap: () => context.go(
                        AppRoutes.therapistParticipant(p.patient.id),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
