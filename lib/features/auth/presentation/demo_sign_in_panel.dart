import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/page_list.dart';
import '../domain/demo_accounts.dart';
import 'controllers/auth_controller.dart';

/// One tap into each seeded role, so testing the child, parent, therapist and
/// admin areas does not need a phone per role. The welcome page shows it only
/// in debug and profile builds.
class DemoSignInPanel extends ConsumerStatefulWidget {
  const DemoSignInPanel({super.key});

  @override
  ConsumerState<DemoSignInPanel> createState() => _DemoSignInPanelState();
}

class _DemoSignInPanelState extends ConsumerState<DemoSignInPanel> {
  DemoAccount? _signingIn;

  Future<void> _signIn(DemoAccount account) async {
    setState(() => _signingIn = account);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final auth = ref.read(authControllerProvider.notifier);
    var signedIn = true;
    final reached = await runWithFailureMessage(context, () async {
      switch (account) {
        case DemoAccount.child:
          await auth.setUpChild(
            parentCode: DemoAccounts.parentCode,
            childName: DemoAccounts.childName,
          );
        case DemoAccount.parent:
          signedIn = await _signInWithEmail(auth, DemoAccounts.parentEmail);
        case DemoAccount.therapist:
          signedIn = await _signInWithEmail(auth, DemoAccounts.therapistEmail);
        case DemoAccount.admin:
          signedIn = await _signInWithEmail(auth, DemoAccounts.adminEmail);
      }
    });
    // A rejected password means the service is running without the demo seed.
    if (reached && !signedIn) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.demoSignInFailed)));
    }
    if (mounted) setState(() => _signingIn = null);
  }

  Future<bool> _signInWithEmail(AuthController auth, String email) =>
      auth.signIn(email: email, password: DemoAccounts.password);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      DemoAccount.child: (LucideIcons.smile, l10n.demoSignInChild),
      DemoAccount.parent: (LucideIcons.heartHandshake, l10n.demoSignInParent),
      DemoAccount.therapist: (
        LucideIcons.stethoscope,
        l10n.demoSignInTherapist,
      ),
      DemoAccount.admin: (LucideIcons.shieldCheck, l10n.demoSignInAdmin),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.demoSignInTitle),
        for (final MapEntry(key: account, value: (icon, label))
            in labels.entries) ...[
          SecondaryButton(
            icon: icon,
            label: _signingIn == account ? l10n.demoSignInWorking : label,
            onPressed: _signingIn == null ? () => _signIn(account) : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
