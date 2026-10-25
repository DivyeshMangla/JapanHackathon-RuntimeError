import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// Hands this phone to [child] after the parent confirms. Child mode ends
/// the parent's session, so the dialog asks for a PIN to leave.
class StartChildModeButton extends ConsumerStatefulWidget {
  const StartChildModeButton({
    super.key,
    required this.child,
    this.primary = false,
  });

  final User child;

  /// The page's main action uses the primary style; a card uses secondary.
  final bool primary;

  @override
  ConsumerState<StartChildModeButton> createState() =>
      _StartChildModeButtonState();
}

class _StartChildModeButtonState extends ConsumerState<StartChildModeButton> {
  bool _starting = false;

  Future<void> _start() async {
    final l10n = context.l10n;
    final name = widget.child.firstName;
    var chosenPin = '';
    var showPinError = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          scrollable: true,
          title: Text(l10n.childModeStartTitle(name)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.childModeStartBody(name)),
              TextField(
                onChanged: (value) => chosenPin = value,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.childModeParentPassword,
                  errorText: showPinError
                      ? l10n.childModePasswordRequired
                      : null,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                if (chosenPin.length != 4) {
                  updateDialog(() => showPinError = true);
                  return;
                }
                Navigator.pop(dialog, true);
              },
              child: Text(l10n.childModeStartAction),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _starting = true);
    await runWithFailureMessage(
      context,
      () => ref
          .read(authControllerProvider.notifier)
          .startChildMode(widget.child, chosenPin),
    );
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = _starting
        ? l10n.childModeStarting
        : l10n.childModeStart(widget.child.firstName);
    final onPressed = _starting ? null : _start;
    return widget.primary
        ? PrimaryButton(
            label: label,
            icon: LucideIcons.smile,
            onPressed: onPressed,
          )
        : SecondaryButton(
            label: label,
            icon: LucideIcons.smile,
            onPressed: onPressed,
          );
  }
}
