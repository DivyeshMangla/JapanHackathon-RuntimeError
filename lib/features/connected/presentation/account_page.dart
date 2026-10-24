import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../data/connected_service.dart';
import 'connected_actions.dart';
import 'patient_sections.dart';

const _minPasswordLength = 10;
const _maxPasswordLength = 128;

/// The signed-in account: who it is, sign-out, and a password change, which
/// signs out everywhere because the server ends every session.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.service});

  final ConnectedService service;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> with ConnectedActions {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  ConnectedService get service => widget.service;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_form.currentState!.validate()) return;
    await service.changePassword(_current.text, _next.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = service.user;
    final passwordLimit = [
      LengthLimitingTextInputFormatter(_maxPasswordLength),
    ];
    return ActionPage(
      title: l10n.connectedAccountTitle,
      onBack: busy ? null : () => Navigator.pop(context),
      backLabel: l10n.connectedBack,
      error: error,
      actions: [
        SecondaryButton(
          label: label('signOut', l10n.signOut),
          icon: LucideIcons.logOut,
          onPressed: action('signOut', service.signOut),
        ),
      ],
      children: [
        if (user != null)
          SectionCard(
            title: user.name,
            child: Text(
              user.email,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (service.outbox.isNotEmpty)
          InfoNotice(
            '${l10n.connectedOutbox(service.outbox.length)} '
            '${l10n.connectedOutboxKept}',
            icon: LucideIcons.cloudUpload,
          ),
        FormSection(
          title: l10n.connectedChangePassword,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledTextField(
                  label: l10n.connectedCurrentPassword,
                  controller: _current,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  inputFormatters: passwordLimit,
                  enabled: !busy,
                  validator: (value) => (value ?? '').isEmpty
                      ? l10n.connectedFieldRequired
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                LabeledTextField(
                  label: l10n.connectedNewPassword,
                  hint: l10n.connectedPasswordRule,
                  controller: _next,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  inputFormatters: passwordLimit,
                  enabled: !busy,
                  validator: (value) =>
                      (value ?? '').length < _minPasswordLength
                      ? l10n.connectedPasswordRule
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: label('password', l10n.connectedChangePasswordSubmit),
                  onPressed: action('password', _changePassword),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
