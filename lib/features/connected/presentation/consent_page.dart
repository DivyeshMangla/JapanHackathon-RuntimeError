import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../setup/presentation/signature_pad.dart';
import '../data/connected_service.dart';
import '../domain/connected_models.dart';
import 'connected_actions.dart';

/// The patient reads the study information, answers each statement and
/// signs. Signing is offered only once every required statement is ticked.
class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key, required this.service});

  final ConnectedService service;

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> with ConnectedActions {
  final _signer = TextEditingController();

  @override
  void dispose() {
    _signer.dispose();
    super.dispose();
  }

  final _answers = {
    for (final statement in ConsentStatement.values) statement: false,
  };

  @override
  ConnectedService get service => widget.service;

  bool get _readyToSign => ConsentStatement.values
      .where((statement) => statement.isRequired)
      .every((statement) => _answers[statement]!);

  Future<void> _submit(List<int> png) async {
    final navigator = Navigator.of(context);
    final submitted = await run(
      'submit',
      () => service.submitConsent(
        answers: _answers,
        signaturePng: png,
        signerName: _signer.text.trim(),
      ),
    );
    if (submitted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final consentText = service.config.consentText;
    String statementText(ConsentStatement statement) => switch (statement) {
      ConsentStatement.adult => l10n.connectedConsentAdult,
      ConsentStatement.participation => l10n.connectedConsentParticipation,
      ConsentStatement.dataSharing => l10n.connectedConsentDataSharing,
      ConsentStatement.analysis => l10n.connectedConsentAnalysis,
    };
    return ActionPage(
      title: l10n.connectedConsentTitle,
      onBack: busy ? null : () => Navigator.pop(context),
      backLabel: l10n.connectedBack,
      error: error,
      children: [
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(l10n.connectedStudyInformation),
              Text(
                consentText.isEmpty
                    ? l10n.connectedConsentUnavailable
                    : consentText,
                style: text.bodyLarge,
              ),
            ],
          ),
        ),
        for (final statement in ConsentStatement.values)
          InkCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(statementText(statement)),
              subtitle: Text(
                statement.isRequired
                    ? l10n.connectedRequired
                    : l10n.connectedOptional,
              ),
              value: _answers[statement],
              onChanged: busy
                  ? null
                  : (value) =>
                        setState(() => _answers[statement] = value == true),
            ),
          ),
        LabeledTextField(
          controller: _signer,
          label: l10n.motorSignerName,
          onChanged: (_) => setState(() {}),
          enabled: !busy,
        ),
        SectionLabel(l10n.connectedSignHeading),
        if (_readyToSign && _signer.text.trim().isNotEmpty)
          SignaturePad(
            onSave: _submit,
            saveLabel: l10n.connectedSubmitConsent,
            savingLabel: l10n.connectedWorking,
            redoLabel: l10n.connectedRedraw,
          )
        else
          InfoNotice(l10n.connectedSignHint),
      ],
    );
  }
}
