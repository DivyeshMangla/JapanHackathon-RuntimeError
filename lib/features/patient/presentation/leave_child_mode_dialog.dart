import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// Asks for the parent's password before handing the device back to them,
/// so a child cannot leave child mode on their own.
class LeaveChildModeDialog extends ConsumerStatefulWidget {
  const LeaveChildModeDialog({super.key});

  @override
  ConsumerState<LeaveChildModeDialog> createState() =>
      _LeaveChildModeDialogState();
}

class _LeaveChildModeDialogState extends ConsumerState<LeaveChildModeDialog> {
  final _password = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final l10n = context.l10n;
    if (_password.text.isEmpty) {
      setState(() => _error = l10n.childModePasswordRequired);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final left = await ref
          .read(authControllerProvider.notifier)
          .endChildMode(_password.text);
      if (!mounted) return;
      if (left) {
        Navigator.pop(context);
        return;
      }
      setState(() => _error = l10n.childModeWrongPassword);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = l10n.failureMessage(failure));
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.childModeLeaveTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.childModeLeaveBody),
          const SizedBox(height: AppSpacing.md),
          LabeledTextField(
            controller: _password,
            label: l10n.childModeParentPassword,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            enabled: !_checking,
            errorText: _error,
            onSubmitted: (_) => _checking ? null : _leave(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _checking ? null : _leave,
          child: Text(
            _checking ? l10n.childModeChecking : l10n.childModeLeaveAction,
          ),
        ),
      ],
    );
  }
}
