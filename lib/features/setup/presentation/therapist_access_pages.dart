import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/setup_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/seal_mark.dart';
import 'setup_actions.dart';

/// The service caps profile fields at this length.
const _maxProfileLength = 200;
const _maxPinLength = 6;

/// The word the service requires before it erases a therapist phone.
const _eraseConfirmation = 'DELETE';

final _digitsOnly = [FilteringTextInputFormatter.digitsOnly];

class TherapistSignupPage extends ConsumerStatefulWidget {
  const TherapistSignupPage({super.key});

  @override
  ConsumerState<TherapistSignupPage> createState() =>
      _TherapistSignupPageState();
}

class _TherapistSignupPageState extends ConsumerState<TherapistSignupPage>
    with SetupActions {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _clinic = TextEditingController();
  final _registration = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _clinic.dispose();
    _registration.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? s('fieldRequired') : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await service.signup(_name.text, _clinic.text, _registration.text);
  }

  @override
  Widget build(BuildContext context) {
    final limit = [LengthLimitingTextInputFormatter(_maxProfileLength)];
    return ActionPage(
      title: s('needsSignup'),
      intro: s('selfDeclared'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('continue'),
          onPressed: action('continue', _submit),
        ),
      ],
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              LabeledTextField(
                label: s('name'),
                controller: _name,
                validator: _required,
                inputFormatters: limit,
                textInputAction: TextInputAction.next,
                enabled: !busy,
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledTextField(
                label: s('clinic'),
                controller: _clinic,
                validator: _required,
                inputFormatters: limit,
                textInputAction: TextInputAction.next,
                enabled: !busy,
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledTextField(
                label: s('registration'),
                controller: _registration,
                validator: _required,
                inputFormatters: limit,
                textInputAction: TextInputAction.done,
                enabled: !busy,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> with SetupActions {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _biometric = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_biometric) {
      final auth = LocalAuthentication();
      if (!await auth.canCheckBiometrics ||
          (await auth.getAvailableBiometrics()).isEmpty) {
        throw const SetupFailure(SetupFailureReason.noBiometric);
      }
    }
    await service.setPin(_pin.text, _confirm.text, _biometric);
    _pin.clear();
    _confirm.clear();
  }

  @override
  Widget build(BuildContext context) {
    final digits = [
      ..._digitsOnly,
      LengthLimitingTextInputFormatter(_maxPinLength),
    ];
    return ActionPage(
      title: s('needsPin'),
      intro: s('pinRules'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('continue'),
          onPressed: action('continue', _submit),
        ),
      ],
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              LabeledTextField(
                label: s('pin'),
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                prefixIcon: LucideIcons.lock,
                textInputAction: TextInputAction.next,
                enabled: !busy,
                validator: (value) => RegExp(r'^\d{4,6}$').hasMatch(value ?? '')
                    ? null
                    : s('pinLength'),
              ),
              const SizedBox(height: AppSpacing.md),
              LabeledTextField(
                label: s('confirmPin'),
                controller: _confirm,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: digits,
                prefixIcon: LucideIcons.lock,
                textInputAction: TextInputAction.done,
                enabled: !busy,
                validator: (value) =>
                    value == _pin.text ? null : s('pinMismatch'),
              ),
            ],
          ),
        ),
        InkCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: SwitchListTile(
            secondary: const Icon(LucideIcons.fingerprint),
            title: Text(s('biometric')),
            value: _biometric,
            onChanged: busy
                ? null
                : (value) => setState(() => _biometric = value),
          ),
        ),
      ],
    );
  }
}

class KeyGenerationPage extends ConsumerStatefulWidget {
  const KeyGenerationPage({super.key});

  @override
  ConsumerState<KeyGenerationPage> createState() => _KeyGenerationPageState();
}

class _KeyGenerationPageState extends ConsumerState<KeyGenerationPage>
    with SetupActions {
  @override
  void initState() {
    super.initState();
    // Key generation needs no input, so it starts as soon as the page shows;
    // Retry covers a failed attempt.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(run('retry', service.generateKeys)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('needsKeys'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('retry'),
          icon: LucideIcons.rotateCcw,
          onPressed: action('retry', service.generateKeys),
        ),
      ],
      children: [
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const SealMark(icon: LucideIcons.keyRound),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(s('keysProgress'))),
            ],
          ),
        ),
      ],
    );
  }
}

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> with SetupActions {
  final _pin = TextEditingController();
  late final Timer _lockoutTimer;
  int _lockedSeconds = 0;

  bool get _locked => _lockedSeconds > 0;

  @override
  void initState() {
    super.initState();
    _lockoutTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_updateLockout()),
    );
    unawaited(_updateLockout());
  }

  @override
  void dispose() {
    _lockoutTimer.cancel();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _updateLockout() async {
    final remaining = await service.remainingLockout();
    if (mounted) {
      setState(() => _lockedSeconds = (remaining.inMilliseconds / 1000).ceil());
    }
  }

  Future<void> _unlock() async {
    final unlocked = await service.unlock(_pin.text);
    _pin.clear();
    await _updateLockout();
    if (!unlocked) throw const SetupFailure(SetupFailureReason.wrongPin);
  }

  Future<void> _unlockWithBiometrics() => service.unlockBiometric(
    () => LocalAuthentication().authenticate(
      localizedReason: s('unlockButton'),
      biometricOnly: true,
    ),
  );

  Future<void> _erase() async {
    final typed = await showDialog<String>(
      context: context,
      builder: (_) => _EraseDialog(
        title: s('forgotPin'),
        warning: s('wipeWarning'),
        fieldLabel: s('typeDelete'),
        cancelLabel: s('cancel'),
        eraseLabel: s('erase'),
      ),
    );
    if (typed != null) await service.resetTherapist(typed);
  }

  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('unlock'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('unlockButton'),
          icon: LucideIcons.lockOpen,
          onPressed: action('unlockButton', _unlock, enabled: !_locked),
        ),
        if (service.biometrics)
          SecondaryButton(
            label: label('biometric'),
            icon: LucideIcons.fingerprint,
            onPressed: action(
              'biometric',
              _unlockWithBiometrics,
              enabled: !_locked,
            ),
          ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          onPressed: action('forgotPin', _erase),
          child: Text(label('forgotPin')),
        ),
      ],
      children: [
        LabeledTextField(
          label: s('pin'),
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            ..._digitsOnly,
            LengthLimitingTextInputFormatter(_maxPinLength),
          ],
          prefixIcon: LucideIcons.lock,
          textInputAction: TextInputAction.done,
          enabled: !busy,
          errorText: _locked
              ? format('lockedFor', {'seconds': _lockedSeconds})
              : null,
          onSubmitted: (_) => action('unlockButton', _unlock)?.call(),
        ),
      ],
    );
  }
}

/// Pops the typed confirmation, or null when cancelled. Erase stays disabled
/// until the confirmation word matches, so a stray tap cannot wipe the phone.
class _EraseDialog extends StatefulWidget {
  const _EraseDialog({
    required this.title,
    required this.warning,
    required this.fieldLabel,
    required this.cancelLabel,
    required this.eraseLabel,
  });

  final String title;
  final String warning;
  final String fieldLabel;
  final String cancelLabel;
  final String eraseLabel;

  @override
  State<_EraseDialog> createState() => _EraseDialogState();
}

class _EraseDialogState extends State<_EraseDialog> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _typed.text == _eraseConfirmation;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.warning),
            const SizedBox(height: AppSpacing.md),
            LabeledTextField(
              label: widget.fieldLabel,
              controller: _typed,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: confirmed
              ? () => Navigator.pop(context, _typed.text)
              : null,
          child: Text(widget.eraseLabel),
        ),
      ],
    );
  }
}
