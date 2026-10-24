import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import 'account_validators.dart';
import 'controllers/auth_controller.dart';

/// A parent opens their child's practice on this device with the code from
/// their Settings screen. The child never types an email or password.
class ChildSetupScreen extends ConsumerStatefulWidget {
  const ChildSetupScreen({super.key});

  @override
  ConsumerState<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends ConsumerState<ChildSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .setUpChild(parentCode: _code.text, childName: _name.text);
    } on AppFailure catch (failure) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = l10n.failureMessage(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ActionPage(
      title: l10n.childSetupTitle,
      intro: l10n.childSetupIntro,
      onBack: _submitting ? null : () => context.pop(),
      backLabel: l10n.back,
      error: _error,
      actions: [
        PrimaryButton(
          label: _submitting
              ? l10n.childSetupSubmitting
              : l10n.childSetupSubmit,
          icon: LucideIcons.sparkles,
          onPressed: _submitting ? null : _submit,
        ),
      ],
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledTextField(
                label: l10n.childSetupParentCode,
                hint: l10n.childSetupParentCodeHint,
                controller: _code,
                prefixIcon: LucideIcons.keyRound,
                textInputAction: TextInputAction.next,
                enabled: !_submitting,
                validator: (v) => requiredText(l10n, v),
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledTextField(
                label: l10n.childSetupName,
                hint: l10n.childSetupNameHint,
                controller: _name,
                prefixIcon: LucideIcons.smile,
                textInputAction: TextInputAction.done,
                enabled: !_submitting,
                validator: (v) => requiredName(l10n, v),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        InfoNotice(l10n.childSetupNote),
      ],
    );
  }
}
