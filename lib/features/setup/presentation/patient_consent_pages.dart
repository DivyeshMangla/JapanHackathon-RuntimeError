import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/setup_failure.dart';
import '../../../core/setup_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/therapist_directory.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../narration_source.dart';
import '../setup_service.dart';
import 'setup_actions.dart';
import 'signature_pad.dart';
import 'transfer_buttons.dart';

class JoinTherapistPage extends ConsumerStatefulWidget {
  const JoinTherapistPage({super.key});

  @override
  ConsumerState<JoinTherapistPage> createState() => _JoinTherapistPageState();
}

class _JoinTherapistPageState extends ConsumerState<JoinTherapistPage>
    with SetupActions {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    if (!_form.currentState!.validate()) return;
    await LocalTherapistDirectory().resolve(_code.text);
    // The local directory resolves nothing until a hospital backend exists.
    throw const SetupFailure(SetupFailureReason.codeUnavailable);
  }

  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('needsJoin'),
      intro: s('confirmTherapist'),
      error: error,
      actions: [
        TransferButtons(
          sending: false,
          qrLabel: label('scanQr'),
          fileLabel: label('importFile'),
          onQr: action('scanQr', () => receive(qr: true, accept: service.join)),
          onFile: action(
            'importFile',
            () => receive(qr: false, accept: service.join),
          ),
        ),
      ],
      children: [
        Form(
          key: _form,
          child: LabeledTextField(
            label: s('joinCodeInput'),
            controller: _code,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            enabled: !busy,
            validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                ? null
                : s('sixDigits'),
          ),
        ),
        SecondaryButton(
          label: label('lookupCode'),
          onPressed: action('lookupCode', _lookUp),
        ),
        InfoNotice(s('codeUnavailable')),
      ],
    );
  }
}

class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage> with SetupActions {
  static const _languages = {
    'en': 'languageEnglish',
    'hi': 'languageHindi',
    'pa': 'languagePunjabi',
  };

  String _language = 'en';

  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('language'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('continue'),
          onPressed: action(
            'continue',
            () => service.selectLanguage(_language),
          ),
        ),
      ],
      children: [
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(LucideIcons.stethoscope, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '${service.therapist!.name} · ${service.therapist!.clinic}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        InfoNotice(s('confirmTherapist'), icon: LucideIcons.shieldCheck),
        ChoicePills<String>(
          options: _languages.keys.toList(),
          selected: _language,
          labelOf: (code) => s(_languages[code]!),
          onSelected: busy ? null : (code) => setState(() => _language = code),
        ),
      ],
    );
  }
}

class StudyInformationPage extends ConsumerStatefulWidget {
  const StudyInformationPage({super.key});

  @override
  ConsumerState<StudyInformationPage> createState() =>
      _StudyInformationPageState();
}

class _StudyInformationPageState extends ConsumerState<StudyInformationPage>
    with SetupActions {
  final _narration = OfflineNarrationSource();
  int _wordStart = 0;
  int _wordEnd = 0;

  @override
  void dispose() {
    unawaited(_narration.dispose());
    super.dispose();
  }

  Future<void> _play(String text) =>
      _narration.play('information', service.locale, text, (start, end) {
        if (mounted) {
          setState(() {
            _wordStart = start;
            _wordEnd = end;
          });
        }
      });

  Future<void> _finish() async {
    await _narration.stop();
    await service.readInformation();
  }

  @override
  Widget build(BuildContext context) {
    final text = s('informationText');
    final body = Theme.of(context).textTheme.bodyLarge;
    final start = _wordStart.clamp(0, text.length);
    final end = _wordEnd.clamp(start, text.length);
    return ActionPage(
      title: s('information'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('haveRead'),
          onPressed: action('haveRead', _finish),
        ),
      ],
      children: [
        PlaceholderNotice(s('placeholder')),
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: text.substring(0, start)),
                TextSpan(
                  text: text.substring(start, end),
                  style: body?.copyWith(backgroundColor: AppColors.sealTint),
                ),
                TextSpan(text: text.substring(end)),
              ],
            ),
            style: body,
          ),
        ),
        SecondaryButton(
          label: label('play'),
          icon: LucideIcons.play,
          onPressed: action('play', () => _play(text)),
        ),
        // Stop stays enabled while narration plays, which is the time the
        // play action is still running.
        SecondaryButton(
          label: s('stop'),
          icon: LucideIcons.square,
          onPressed: () => unawaited(_narration.stop()),
        ),
      ],
    );
  }
}

class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> with SetupActions {
  @override
  Widget build(BuildContext context) {
    final checks = service.draftChecks;
    return ActionPage(
      title: s('consent'),
      error: error,
      actions: [
        PrimaryButton(
          label: label('agree'),
          onPressed: action(
            'agree',
            service.agree,
            enabled: ConsentItem.values
                .where((item) => item.isRequired)
                .every((item) => checks[item] == true),
          ),
        ),
      ],
      children: [
        PlaceholderNotice(s('placeholder')),
        for (final item in ConsentItem.values)
          _ConsentItem(
            title: s(consentLabelKey(item)),
            requirement: s(item.isRequired ? 'required' : 'optional'),
            acknowledgement: s('consentAcknowledge'),
            checked: checks[item] == true,
            onChanged: busy
                ? null
                : (value) => unawaited(
                    run(
                      'consent',
                      () => service.saveChecks({...checks, item: value}),
                    ),
                  ),
          ),
      ],
    );
  }
}

class _ConsentItem extends StatelessWidget {
  const _ConsentItem({
    required this.title,
    required this.requirement,
    required this.acknowledgement,
    required this.checked,
    required this.onChanged,
  });

  final String title;
  final String requirement;
  final String acknowledgement;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(label: requirement),
            ],
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(acknowledgement),
            value: checked,
            onChanged: onChanged == null
                ? null
                : (value) => onChanged!(value == true),
          ),
        ],
      ),
    );
  }
}

class SignaturePage extends ConsumerStatefulWidget {
  const SignaturePage({super.key});

  @override
  ConsumerState<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends ConsumerState<SignaturePage>
    with SetupActions {
  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('signature'),
      intro: s('signatureHelp'),
      error: error,
      children: [
        PlaceholderNotice(s('placeholder')),
        SignaturePad(
          onSave: (png) => run('saveSignature', () => service.signConsent(png)),
          saveLabel: s('saveSignature'),
          savingLabel: s('working'),
          redoLabel: s('redo'),
        ),
      ],
    );
  }
}

class SendConsentPage extends ConsumerStatefulWidget {
  const SendConsentPage({super.key});

  @override
  ConsumerState<SendConsentPage> createState() => _SendConsentPageState();
}

class _SendConsentPageState extends ConsumerState<SendConsentPage>
    with SetupActions {
  Future<void> _send({required bool qr}) async {
    final sent = await send(qr: qr, envelope: service.consentEnvelope);
    if (sent && service.state.stage == SetupStage.sendConsent) {
      await service.markConsentSent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('sendConsent'),
      error: error,
      actions: [
        TransferButtons(
          sending: true,
          qrLabel: label('showQr'),
          fileLabel: label('exportFile'),
          onQr: action('showQr', () => _send(qr: true)),
          onFile: action('exportFile', () => _send(qr: false)),
        ),
        TextButton(
          onPressed: action('sentConfirmed', service.markConsentSent),
          child: Text(label('sentConfirmed')),
        ),
      ],
      children: [InfoNotice(s('sendHelp'), icon: LucideIcons.shieldCheck)],
    );
  }
}
