import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// Hands this phone to [child] after the parent confirms. Child mode ends
/// the parent's session, so the dialog says the password is needed to leave.
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.childModeStartTitle(name)),
        content: Text(l10n.childModeStartBody(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l10n.childModeStartAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _starting = true);
    await runWithFailureMessage(
      context,
      () => ref
          .read(authControllerProvider.notifier)
          .startChildMode(widget.child),
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
