import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/failure_feedback.dart';
import 'controllers/auth_controller.dart';

class SignOutButton extends ConsumerWidget {
  const SignOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: context.l10n.signOut,
      icon: const Icon(LucideIcons.logOut, size: 20),
      onPressed: () => runWithFailureMessage(
        context,
        () => ref.read(authControllerProvider.notifier).signOut(),
      ),
    );
  }
}
