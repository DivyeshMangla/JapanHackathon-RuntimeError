import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n.dart';
import 'buttons.dart';
import 'melo_mark.dart';

/// Cheers the child on after they finish something. The mascot pops in,
/// unless the device asks for reduced motion.
Future<void> showCelebration(BuildContext context, {required String message}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _Celebration(message: message),
    );

class _Celebration extends StatelessWidget {
  const _Celebration({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final still = MediaQuery.disableAnimationsOf(context);
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? 1 : 0.4, end: 1),
            duration: AppMotion.entry,
            curve: Curves.elasticOut,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const MeloMark(size: AppSizes.childMascot),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.celebrationTitle,
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: text.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.celebrationDone,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
