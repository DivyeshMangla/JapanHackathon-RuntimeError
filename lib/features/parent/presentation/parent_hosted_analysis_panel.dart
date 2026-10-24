import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../domain/hosted_analysis.dart';
import 'controllers/hosted_analysis_controllers.dart';
import 'hosted_analysis_strings.dart';

/// Permission lives in the parent's dashboard; child mode cannot grant it.
class ParentHostedAnalysisPanel extends ConsumerStatefulWidget {
  const ParentHostedAnalysisPanel({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ParentHostedAnalysisPanel> createState() =>
      _ParentHostedAnalysisPanelState();
}

class _ParentHostedAnalysisPanelState
    extends ConsumerState<ParentHostedAnalysisPanel> {
  bool _saving = false;

  Future<void> _change(
    HostedAnalysisPermission permission, {
    required bool allowed,
  }) async {
    if (_saving) return;
    final childId = widget.childId;
    if (allowed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _PermissionDialog(permission: permission),
      );
      if (confirmed != true || !mounted || widget.childId != childId) return;
    }
    setState(() => _saving = true);
    await runWithFailureMessage(context, () async {
      await ref
          .read(hostedAnalysisRepositoryProvider)
          .setPermission(
            childId: childId,
            allowed: allowed,
            disclosureVersion: permission.disclosureVersion,
            adultConfirmed: allowed,
          );
      ref.invalidate(hostedAnalysisPermissionProvider(childId));
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => AsyncView(
    value: ref.watch(hostedAnalysisPermissionProvider(widget.childId)),
    loading: const Skeleton(height: AppSizes.minTouchTarget),
    data: (permission) => InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            HostedAnalysisStrings.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            permission.allowed
                ? HostedAnalysisStrings.on
                : HostedAnalysisStrings.off,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(HostedAnalysisStrings.explanation),
          if (!permission.careConsentApproved) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(HostedAnalysisStrings.careConsentRequired),
          ],
          const SizedBox(height: AppSpacing.md),
          if (permission.allowed)
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => _change(permission, allowed: false),
              child: Text(
                _saving
                    ? HostedAnalysisStrings.saving
                    : HostedAnalysisStrings.turnOff,
              ),
            )
          else
            FilledButton(
              onPressed: _saving || !permission.careConsentApproved
                  ? null
                  : () => _change(permission, allowed: true),
              child: Text(
                _saving
                    ? HostedAnalysisStrings.saving
                    : HostedAnalysisStrings.review,
              ),
            ),
        ],
      ),
    ),
  );
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({required this.permission});

  final HostedAnalysisPermission permission;

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(HostedAnalysisStrings.title),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.permission.disclosureText),
            const SizedBox(height: AppSpacing.md),
            SelectableText(
              HostedAnalysisStrings.privacyInformation(
                widget.permission.privacyUrl,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              value: _agreed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(HostedAnalysisStrings.guardianConfirmation),
              onChanged: (value) => setState(() => _agreed = value == true),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text(HostedAnalysisStrings.keepOff),
      ),
      FilledButton(
        onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
        child: const Text(HostedAnalysisStrings.allow),
      ),
    ],
  );
}
