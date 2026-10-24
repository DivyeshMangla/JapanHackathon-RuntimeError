import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/auth_controller.dart';

/// Builds [child] only while someone is signed in. During the frames between
/// sign-out and the redirect to login it renders nothing, so screens below
/// can rely on [currentUserProvider].
class SignedInGate extends ConsumerWidget {
  const SignedInGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.value != null),
    );
    return signedIn ? child : const Scaffold();
  }
}
