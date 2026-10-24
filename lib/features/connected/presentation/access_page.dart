import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../data/connected_service.dart';
import '../domain/connected_models.dart';
import 'connected_actions.dart';

/// The server's limits, checked here first so mistakes show on the field.
const _maxFieldLength = 200;
const _minPasswordLength = 10;
const _maxPasswordLength = 128;
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Sign in, or register as a patient or a therapist. Administrators are
/// turned away: they work in the web dashboard.
class AccessPage extends StatefulWidget {
  const AccessPage({super.key, required this.service});

  final ConnectedService service;

  @override
  State<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends State<AccessPage> with ConnectedActions {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _clinic = TextEditingController();
  final _registration = TextEditingController();
  bool _registering = false;
  bool _obscured = true;
  ConnectedRole _role = ConnectedRole.patient;
  String? _notice;

  @override
  ConnectedService get service => widget.service;

  @override
  void dispose() {
    for (final controller in [
      _email,
      _password,
      _name,
      _clinic,
      _registration,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _notice = null);
    if (!_registering) {
      await service.signIn(_email.text, _password.text);
      return;
    }
    final l10n = context.l10n;
    await service.register(
      Registration(
        role: _role,
        name: _name.text.trim(),
        email: _email.text,
        password: _password.text,
        clinic: _clinic.text.trim(),
        registrationNumber: _registration.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _registering = false;
      _password.clear();
      _notice = _role == ConnectedRole.therapist
          ? l10n.connectedTherapistRegistered
          : l10n.connectedPatientRegistered;
    });
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? context.l10n.connectedFieldRequired : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final syncFailure = service.syncFailure;
    final therapist = _registering && _role == ConnectedRole.therapist;
    final limit = [LengthLimitingTextInputFormatter(_maxFieldLength)];
    return ActionPage(
      title: _registering
          ? l10n.connectedRegisterTitle
          : l10n.connectedSignInTitle,
      intro: l10n.connectedAccessIntro,
      error:
          error ??
          (syncFailure == null
              ? null
              : l10n.connectedFailureMessage(syncFailure)),
      actions: [
        PrimaryButton(
          label: label(
            'submit',
            _registering ? l10n.connectedCreateAccount : l10n.loginSubmit,
          ),
          icon: _registering ? null : LucideIcons.logIn,
          onPressed: action('submit', _submit),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.muted),
          onPressed: busy
              ? null
              : () => setState(() {
                  _registering = !_registering;
                  _notice = null;
                  error = null;
                }),
          child: Text(
            _registering
                ? l10n.connectedHaveAccount
                : l10n.connectedNeedAccount,
          ),
        ),
      ],
      children: [
        if (_notice != null)
          InfoNotice(_notice!, icon: LucideIcons.circleCheck),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_registering) ...[
                  ChoicePills<ConnectedRole>(
                    options: const [
                      ConnectedRole.patient,
                      ConnectedRole.therapist,
                    ],
                    selected: _role,
                    labelOf: (role) => role == ConnectedRole.patient
                        ? l10n.connectedRolePatient
                        : l10n.connectedRoleTherapist,
                    onSelected: busy
                        ? null
                        : (role) => setState(() => _role = role),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LabeledTextField(
                    label: l10n.connectedName,
                    controller: _name,
                    validator: _required,
                    inputFormatters: limit,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    enabled: !busy,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (therapist) ...[
                  LabeledTextField(
                    label: l10n.connectedClinic,
                    controller: _clinic,
                    validator: _required,
                    inputFormatters: limit,
                    textInputAction: TextInputAction.next,
                    enabled: !busy,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LabeledTextField(
                    label: l10n.connectedRegistrationNumber,
                    controller: _registration,
                    validator: _required,
                    inputFormatters: limit,
                    textInputAction: TextInputAction.next,
                    enabled: !busy,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                LabeledTextField(
                  label: l10n.loginEmail,
                  hint: l10n.loginEmailHint,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  prefixIcon: LucideIcons.mail,
                  inputFormatters: limit,
                  textInputAction: TextInputAction.next,
                  enabled: !busy,
                  validator: (value) =>
                      _emailPattern.hasMatch((value ?? '').trim())
                      ? null
                      : l10n.connectedEmailInvalid,
                ),
                const SizedBox(height: AppSpacing.md),
                LabeledTextField(
                  label: l10n.loginPassword,
                  hint: _registering ? l10n.connectedPasswordRule : null,
                  controller: _password,
                  obscureText: _obscured,
                  autofillHints: [
                    _registering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  prefixIcon: LucideIcons.lock,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxPasswordLength),
                  ],
                  textInputAction: TextInputAction.done,
                  enabled: !busy,
                  onSubmitted: (_) => action('submit', _submit)?.call(),
                  validator: (value) => _registering
                      ? ((value ?? '').length < _minPasswordLength
                            ? l10n.connectedPasswordRule
                            : null)
                      : _required(value),
                  suffix: IconButton(
                    tooltip: _obscured
                        ? l10n.loginShowPassword
                        : l10n.loginHidePassword,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                    icon: Icon(
                      _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
