import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import 'account_validators.dart';
import 'controllers/auth_controller.dart';

/// A parent joins their therapist's caseload with the therapist's code.
/// Signing up signs them in, and the router takes them to the parent area.
class ParentSignUpScreen extends ConsumerStatefulWidget {
  const ParentSignUpScreen({super.key});

  @override
  ConsumerState<ParentSignUpScreen> createState() => _ParentSignUpScreenState();
}

class _ParentSignUpScreenState extends ConsumerState<ParentSignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
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
          .registerParent(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            therapistCode: _code.text,
          );
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
      title: l10n.signUpTitle,
      intro: l10n.signUpIntro,
      onBack: _submitting ? null : () => context.pop(),
      backLabel: l10n.back,
      error: _error,
      actions: [
        PrimaryButton(
          label: _submitting ? l10n.creatingAccount : l10n.createAccount,
          icon: LucideIcons.userPlus,
          onPressed: _submitting ? null : _submit,
        ),
        SecondaryButton(
          label: l10n.signUpHaveAccount,
          icon: LucideIcons.logIn,
          onPressed: _submitting
              ? null
              : () => context.pushReplacement(AppRoutes.login),
        ),
      ],
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledTextField(
                  label: l10n.signUpTherapistCode,
                  hint: l10n.signUpTherapistCodeHint,
                  controller: _code,
                  prefixIcon: LucideIcons.keyRound,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  validator: (v) => requiredText(l10n, v),
                ),
                const SizedBox(height: AppSpacing.md),
                LabeledTextField(
                  label: l10n.fullName,
                  controller: _name,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  validator: (v) => requiredName(l10n, v),
                ),
                const SizedBox(height: AppSpacing.md),
                LabeledTextField(
                  label: l10n.loginEmail,
                  hint: l10n.loginEmailHint,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                  validator: (v) => validEmail(l10n, v),
                ),
                const SizedBox(height: AppSpacing.md),
                LabeledTextField(
                  label: l10n.loginPassword,
                  hint: l10n.signUpPasswordHint,
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  enabled: !_submitting,
                  validator: (v) => validPassword(l10n, v),
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
