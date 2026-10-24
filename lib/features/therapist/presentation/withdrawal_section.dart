import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../study/domain/participant_record.dart';
import '../../study/presentation/controllers/study_controllers.dart';

/// Records a participant leaving the study. Withdrawal feeds the retention
/// rate and stops questionnaires; their data is kept, as consent allows.
class WithdrawalSection extends ConsumerWidget {
  const WithdrawalSection({super.key, required this.record});

  final ParticipantRecord record;

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _WithdrawDialog(),
    );
    if (reason == null || !context.mounted) return;
    await runWithFailureMessage(
      context,
      () => ref.read(studyRecordActionsProvider).withdraw(record, reason),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final withdrawnOn = record.withdrawnOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.withdrawalSection),
        if (withdrawnOn != null)
          InkCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.userMinus,
                  size: 20,
                  color: AppColors.seal,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.withdrawnOn(formatFullDate(withdrawnOn)),
                        style: text.titleMedium,
                      ),
                      Text(record.withdrawalReason, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text(l10n.withdrawalHelp, style: text.bodySmall),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: l10n.recordWithdrawal,
            icon: LucideIcons.userMinus,
            onPressed: () => _withdraw(context, ref),
          ),
        ],
      ],
    );
  }
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog();

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _reason = TextEditingController();
  bool _attempted = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_reason.text.trim().isEmpty) {
      setState(() => _attempted = true);
      return;
    }
    Navigator.of(context).pop(_reason.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.recordWithdrawal),
      content: LabeledTextField(
        label: l10n.withdrawalReasonLabel,
        controller: _reason,
        maxLines: 3,
        errorText: _attempted && _reason.text.trim().isEmpty
            ? l10n.fieldRequired
            : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _confirm, child: Text(l10n.recordWithdrawal)),
      ],
    );
  }
}
