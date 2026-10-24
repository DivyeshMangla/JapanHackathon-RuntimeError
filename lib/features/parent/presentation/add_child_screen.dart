import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/signature_pad.dart';
import '../../../shared/widgets/skeleton.dart';
import '../domain/consent.dart';
import 'controllers/family_controllers.dart';

/// The parent names their child, reads the consent, answers each statement
/// and signs. This is the only place consent is asked for: the child's
/// account and the signature are created together. Signing is offered only
/// once the name and every required statement are filled in.
class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final _childName = TextEditingController();
  final _signer = TextEditingController();
  final _agreed = <ConsentStatement>{};
  bool _signing = false;
  String? _error;

  @override
  void dispose() {
    _childName.dispose();
    _signer.dispose();
    super.dispose();
  }

  bool get _readyToSign =>
      ConsentStatement.values
          .where((statement) => statement.isRequired)
          .every(_agreed.contains) &&
      _childName.text.trim().isNotEmpty &&
      _signer.text.trim().isNotEmpty;

  Future<void> _sign(List<int> png) async {
    final l10n = context.l10n;
    setState(() {
      _signing = true;
      _error = null;
    });
    try {
      await ref
          .read(familyActionsProvider)
          .addChild(
            childName: _childName.text,
            signerName: _signer.text,
            agreed: _agreed,
            signaturePng: png,
          );
      if (mounted) context.pop();
    } on AppFailure catch (failure) {
      if (mounted) {
        setState(() {
          _signing = false;
          _error = l10n.failureMessage(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final form = ref.watch(consentFormProvider);
    String statementText(ConsentStatement statement) => switch (statement) {
      ConsentStatement.adult => l10n.consentAdult,
      ConsentStatement.participation => l10n.consentParticipation,
      ConsentStatement.dataSharing => l10n.consentDataSharing,
      ConsentStatement.analysis => l10n.consentAnalysis,
    };
    return ActionPage(
      title: l10n.addChildTitle,
      intro: l10n.addChildIntro,
      onBack: _signing ? null : () => context.pop(),
      backLabel: l10n.back,
      error: _error,
      children: [
        LabeledTextField(
          controller: _childName,
          label: l10n.addChildName,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          enabled: !_signing,
        ),
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(l10n.consentInformation),
              form.when(
                data: (form) => Text(
                  form.text.isEmpty ? l10n.consentUnavailable : form.text,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                loading: () =>
                    const Skeleton(height: AppSizes.signaturePreview),
                error: (error, _) => Text(
                  error is AppFailure
                      ? l10n.failureMessage(error)
                      : l10n.consentUnavailable,
                ),
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
                    ? l10n.consentRequiredItem
                    : l10n.consentOptionalItem,
              ),
              value: _agreed.contains(statement),
              onChanged: _signing
                  ? null
                  : (value) => setState(
                      () => value == true
                          ? _agreed.add(statement)
                          : _agreed.remove(statement),
                    ),
            ),
          ),
        LabeledTextField(
          controller: _signer,
          label: l10n.consentSignerName,
          onChanged: (_) => setState(() {}),
          enabled: !_signing,
        ),
        SectionLabel(l10n.consentSignHeading),
        if (_readyToSign && form.hasValue)
          SignaturePad(
            onSave: _sign,
            saveLabel: l10n.consentSubmit,
            savingLabel: l10n.consentSubmitting,
            redoLabel: l10n.consentRedraw,
          )
        else
          InfoNotice(l10n.consentSignHint),
      ],
    );
  }
}
