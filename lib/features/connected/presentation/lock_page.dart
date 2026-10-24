import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/connected_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../data/connected_service.dart';
import 'connected_actions.dart';

const _maxPinLength = 6;
final _pinPattern = RegExp(r'^\d{4,6}$');

/// Covers a therapist's workspace: sets the PIN after sign-in, unlocks it
/// later, and replaces a forgotten PIN after the account password is
/// checked online.
class LockPage extends StatefulWidget {
  const LockPage({super.key, required this.service});

  final ConnectedService service;

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> with ConnectedActions {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  final _password = TextEditingController();
  bool _recovering = false;
  bool _biometrics = false;

  @override
  ConnectedService get service => widget.service;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    try {
      if (_recovering) {
        await service.recoverPin(_password.text);
        if (mounted) setState(() => _recovering = false);
      } else if (service.needsPin) {
        if (_biometrics &&
            (await LocalAuthentication().getAvailableBiometrics()).isEmpty) {
          throw const ConnectedFailure(ConnectedFailureReason.noBiometric);
        }
        await service.setPin(_pin.text, _confirm.text, biometrics: _biometrics);
      } else {
        await service.unlock(_pin.text);
      }
    } finally {
      _pin.clear();
      _confirm.clear();
      _password.clear();
    }
  }

  Future<void> _unlockWithBiometrics() {
    final reason = context.l10n.connectedBiometricReason;
    return service.unlockBiometric(
      () => LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settingPin = service.needsPin && !_recovering;
    final digits = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(_maxPinLength),
    ];
    return ActionPage(
      title: service.needsPin
          ? l10n.connectedSetPinTitle
          : l10n.connectedUnlockTitle,
      intro: _recovering ? l10n.connectedRecoverHint : l10n.connectedPinIntro,
      error: error,
      actions: [
        PrimaryButton(
          label: label(
            'submit',
            _recovering
                ? l10n.connectedVerifyAccount
                : settingPin
                ? l10n.connectedSavePin
                : l10n.connectedUnlock,
          ),
          icon: settingPin || _recovering ? null : LucideIcons.lockOpen,
          onPressed: action('submit', _submit),
        ),
        if (service.biometricsEnabled && !service.needsPin && !_recovering)
          SecondaryButton(
            label: label('biometrics', l10n.connectedUnlockBiometrics),
            icon: LucideIcons.fingerprint,
            onPressed: action('biometrics', _unlockWithBiometrics),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            if (!service.needsPin)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                onPressed: busy
                    ? null
                    : () => setState(() {
                        _recovering = !_recovering;
                        error = null;
                      }),
                child: Text(
                  _recovering
                      ? l10n.connectedBackToPin
                      : l10n.connectedForgotPin,
                ),
              ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              onPressed: action('signOut', service.signOut),
              child: Text(label('signOut', l10n.signOut)),
            ),
          ],
        ),
      ],
      children: [
        Form(
          key: _form,
          child: _recovering
              ? LabeledTextField(
                  label: l10n.connectedRecoverPassword,
                  controller: _password,
                  obscureText: true,
                  prefixIcon: LucideIcons.lock,
                  autofillHints: const [AutofillHints.password],
                  enabled: !busy,
                  validator: (value) => (value ?? '').isEmpty
                      ? l10n.connectedFieldRequired
                      : null,
                )
              : Column(
                  children: [
                    LabeledTextField(
                      label: l10n.connectedPin,
                      controller: _pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      prefixIcon: LucideIcons.lock,
                      enabled: !busy,
                      textInputAction: settingPin
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: settingPin
                          ? null
                          : (_) => action('submit', _submit)?.call(),
                      validator: (value) => _pinPattern.hasMatch(value ?? '')
                          ? null
                          : l10n.connectedPinLength,
                    ),
                    if (settingPin) ...[
                      const SizedBox(height: AppSpacing.md),
                      LabeledTextField(
                        label: l10n.connectedConfirmPin,
                        controller: _confirm,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        prefixIcon: LucideIcons.lock,
                        enabled: !busy,
                        validator: (value) => value == _pin.text
                            ? null
                            : l10n.connectedPinMismatch,
                      ),
                    ],
                  ],
                ),
        ),
        if (settingPin)
          InkCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: SwitchListTile(
              secondary: const Icon(LucideIcons.fingerprint),
              title: Text(l10n.connectedEnableBiometrics),
              value: _biometrics,
              onChanged: busy
                  ? null
                  : (value) => setState(() => _biometrics = value),
            ),
          ),
      ],
    );
  }
}
