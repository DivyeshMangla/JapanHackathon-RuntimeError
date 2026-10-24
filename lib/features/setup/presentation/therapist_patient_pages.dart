import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../setup_service.dart';
import 'setup_actions.dart';
import 'transfer_buttons.dart';

const _readyRoute = '/ready';

const _languageKeys = {
  'en': 'languageEnglish',
  'hi': 'languageHindi',
  'pa': 'languagePunjabi',
};
const _exercisesPerPlan = 3;

/// The first block of the participant's UUID, enough to tell a caseload
/// apart at a glance; the review page shows the full id.
String _shortId(String participantId) =>
    participantId.split('-').first.toUpperCase();

String _patientRoute(String page, String participantId) =>
    '/therapist/$page/$participantId';

class TherapistReadyPage extends ConsumerStatefulWidget {
  const TherapistReadyPage({super.key});

  @override
  ConsumerState<TherapistReadyPage> createState() => _TherapistReadyPageState();
}

class _TherapistReadyPageState extends ConsumerState<TherapistReadyPage>
    with SetupActions {
  String _statusLabel(SetupPatientStatus status) => s(switch (status) {
    SetupPatientStatus.pending => 'statusPending',
    SetupPatientStatus.approved => 'statusApproved',
    SetupPatientStatus.planReady => 'planReady',
  });

  @override
  Widget build(BuildContext context) {
    final patients = service.patients;
    final pending = patients.where((p) => !p.isApproved).toList();
    final others = patients.where((p) => p.isApproved).toList();
    return ActionPage(
      title: s('ready'),
      error: error,
      headerAction: IconButton(
        tooltip: s('lock'),
        onPressed: busy ? null : service.lock,
        icon: const Icon(LucideIcons.lock, size: 20),
      ),
      actions: [
        TransferButtons(
          sending: false,
          qrLabel: label('scanQr'),
          fileLabel: label('importFile'),
          onQr: action(
            'scanQr',
            () => receive(qr: true, accept: service.importConsent),
          ),
          onFile: action(
            'importFile',
            () => receive(qr: false, accept: service.importConsent),
          ),
        ),
      ],
      children: [
        _NavigationCard(
          icon: LucideIcons.qrCode,
          title: s('joinCode'),
          onTap: () => context.go('/therapist/join'),
        ),
        if (patients.isEmpty)
          InfoNotice(s('noPatients'), icon: LucideIcons.inbox),
        if (pending.isNotEmpty)
          _PatientGroup(
            title: s('pending'),
            patients: pending,
            statusLabel: _statusLabel,
          ),
        if (others.isNotEmpty)
          _PatientGroup(
            title: s('approved'),
            patients: others,
            statusLabel: _statusLabel,
          ),
      ],
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.titleStyle,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkCard(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: titleStyle ?? Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: AppSpacing.sm),
              ],
              const Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: AppColors.wash,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientGroup extends StatelessWidget {
  const _PatientGroup({
    required this.title,
    required this.patients,
    required this.statusLabel,
  });

  final String title;
  final List<SetupPatient> patients;
  final String Function(SetupPatientStatus status) statusLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        for (final patient in patients)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _NavigationCard(
              icon: LucideIcons.userRound,
              title: _shortId(patient.id),
              titleStyle: AppTypography.monoLarge,
              trailing: StatusPill(
                label: statusLabel(patient.status),
                highlighted: !patient.isApproved,
              ),
              onTap: () => context.go(_patientRoute('patient', patient.id)),
            ),
          ),
      ],
    );
  }
}

class JoinCodePage extends ConsumerStatefulWidget {
  const JoinCodePage({super.key});

  @override
  ConsumerState<JoinCodePage> createState() => _JoinCodePageState();
}

class _JoinCodePageState extends ConsumerState<JoinCodePage> with SetupActions {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final profile = service.profile!;
    return ActionPage(
      title: s('joinCode'),
      error: error,
      onBack: () => context.go(_readyRoute),
      backLabel: s('back'),
      actions: [
        TransferButtons(
          sending: true,
          qrLabel: label('showQr'),
          fileLabel: label('exportFile'),
          onQr: action(
            'showQr',
            () => send(qr: true, envelope: () async => service.joinEnvelope()),
          ),
          onFile: action(
            'exportFile',
            () => send(qr: false, envelope: () async => service.joinEnvelope()),
          ),
        ),
      ],
      children: [
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile.name} · ${profile.clinic}',
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(service.code, style: AppTypography.monoDisplay),
            ],
          ),
        ),
        InfoNotice(s('codeUnavailable')),
        InfoNotice(s('joinPublic'), icon: LucideIcons.shieldCheck),
      ],
    );
  }
}

class ConsentReviewPage extends ConsumerStatefulWidget {
  const ConsentReviewPage({super.key, required this.participantId});

  final String participantId;

  @override
  ConsumerState<ConsentReviewPage> createState() => _ConsentReviewPageState();
}

class _ConsentReviewPageState extends ConsumerState<ConsentReviewPage>
    with SetupActions {
  bool _paperCopy = false;

  String get _id => widget.participantId;

  @override
  Widget build(BuildContext context) {
    final patient = service.patient(_id);
    if (patient == null) {
      return ActionPage(
        title: s('reviewConsent'),
        onBack: () => context.go(_readyRoute),
        backLabel: s('back'),
        children: [InfoNotice(s('noPatients'), icon: LucideIcons.inbox)],
      );
    }
    final consent = patient.consent;
    final pending = !patient.isApproved;
    return ActionPage(
      title: s('reviewConsent'),
      error: error,
      onBack: () => context.go(_readyRoute),
      backLabel: s('back'),
      actions: pending
          ? [
              PrimaryButton(
                label: label('approve'),
                icon: LucideIcons.penLine,
                onPressed: action(
                  'approve',
                  () => service.approve(_id, _paperCopy),
                  enabled: _paperCopy,
                ),
              ),
            ]
          : [
              PrimaryButton(
                label: s('forms'),
                onPressed: () => context.go(_patientRoute('forms', _id)),
              ),
              if (patient.hasForms)
                SecondaryButton(
                  label: s('prescribe'),
                  onPressed: () => context.go(_patientRoute('prescribe', _id)),
                ),
              if (patient.hasPlan)
                SecondaryButton(
                  label: s('transfer'),
                  onPressed: () => context.go(_patientRoute('transfer', _id)),
                ),
            ],
      children: [
        Text(_id, style: AppTypography.participantCode),
        InfoNotice(s('signatureVerified'), icon: LucideIcons.shieldCheck),
        PlaceholderNotice(s('placeholder')),
        _ConsentRecordCard(
          title: s('consentDetails'),
          details: [
            consent.version,
            consent.signedAt.toIso8601String(),
            s(_languageKeys[consent.locale] ?? 'languageEnglish'),
          ],
          items: {
            for (final MapEntry(key: item, value: agreed)
                in consent.checks.entries)
              s(consentLabelKey(item)): agreed,
          },
          signaturePng: consent.signaturePng,
          invalidSignatureLabel: s('invalidSignatureImage'),
          agreedLabel: s('agreed'),
          declinedLabel: s('declined'),
        ),
        if (pending)
          InkCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: CheckboxListTile(
              title: Text(s('paperCopy')),
              value: _paperCopy,
              onChanged: busy
                  ? null
                  : (value) => setState(() => _paperCopy = value == true),
            ),
          )
        else
          InfoNotice(s('countersigned'), icon: LucideIcons.circleCheck),
      ],
    );
  }
}

class _ConsentRecordCard extends StatelessWidget {
  const _ConsentRecordCard({
    required this.title,
    required this.details,
    required this.items,
    required this.signaturePng,
    required this.invalidSignatureLabel,
    required this.agreedLabel,
    required this.declinedLabel,
  });

  final String title;
  final List<String> details;

  /// Each consent item's label and whether the patient agreed to it.
  final Map<String, bool> items;
  final Uint8List signaturePng;
  final String invalidSignatureLabel;
  final String agreedLabel;
  final String declinedLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final detail in details)
            Text(detail, style: AppTypography.monoSmall),
          const SizedBox(height: AppSpacing.md),
          for (final MapEntry(key: item, value: agreed) in items.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    agreed ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 20,
                    color: agreed ? AppColors.ink : AppColors.wash,
                    semanticLabel: agreed ? agreedLabel : declinedLabel,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(item, style: text.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: ColoredBox(
              color: AppColors.washTint,
              child: Image.memory(
                signaturePng,
                height: AppSizes.signaturePreview,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(invalidSignatureLabel, style: text.bodySmall),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientFormsPage extends ConsumerStatefulWidget {
  const PatientFormsPage({super.key, required this.participantId});

  final String participantId;

  @override
  ConsumerState<PatientFormsPage> createState() => _PatientFormsPageState();
}

class _PatientFormsPageState extends ConsumerState<PatientFormsPage>
    with SetupActions {
  final _form = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _demographic = TextEditingController();
  final _clinical = TextEditingController();

  @override
  void dispose() {
    _age.dispose();
    _demographic.dispose();
    _clinical.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await service.saveForms(
      widget.participantId,
      ParticipantForms(
        age: int.parse(_age.text),
        demographic: _demographic.text,
        clinical: _clinical.text,
      ),
    );
    if (mounted) {
      context.go(_patientRoute('prescribe', widget.participantId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final approved = service.patient(widget.participantId)?.isApproved ?? false;
    return ActionPage(
      title: s('forms'),
      error: error,
      onBack: () => context.go(_readyRoute),
      backLabel: s('back'),
      actions: [
        if (approved)
          PrimaryButton(
            label: label('saveForms'),
            onPressed: action('saveForms', _save),
          ),
      ],
      children: [
        if (!approved)
          InfoNotice(s('approvalRequired'), icon: LucideIcons.lock)
        else ...[
          InfoNotice(s('formsPrivacy'), icon: LucideIcons.shieldCheck),
          Form(
            key: _form,
            child: Column(
              children: [
                LabeledTextField(
                  label: s('age'),
                  controller: _age,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  enabled: !busy,
                  validator: (value) {
                    final age = int.tryParse(value ?? '') ?? 0;
                    return age < 18 || age > 120 ? s('adultAge') : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                LabeledTextField(
                  label: s('demographic'),
                  controller: _demographic,
                  maxLines: 2,
                  enabled: !busy,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? s('fieldRequired') : null,
                ),
                const SizedBox(height: AppSpacing.md),
                LabeledTextField(
                  label: s('clinical'),
                  controller: _clinical,
                  maxLines: 3,
                  enabled: !busy,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? s('fieldRequired') : null,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class PrescribePage extends ConsumerStatefulWidget {
  const PrescribePage({super.key, required this.participantId});

  final String participantId;

  @override
  ConsumerState<PrescribePage> createState() => _PrescribePageState();
}

class _PrescribePageState extends ConsumerState<PrescribePage>
    with SetupActions {
  final _form = GlobalKey<FormState>();
  final _dose = TextEditingController();
  Set<String> _selected = {};

  @override
  void dispose() {
    _dose.dispose();
    super.dispose();
  }

  Future<void> _makePlan() async {
    if (!_form.currentState!.validate()) return;
    await service.prescribe(
      widget.participantId,
      _selected.toList(),
      int.parse(_dose.text),
    );
    if (mounted) {
      context.go(_patientRoute('transfer', widget.participantId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ActionPage(
      title: s('prescribe'),
      error: error,
      onBack: () => context.go(_readyRoute),
      backLabel: s('back'),
      actions: [
        PrimaryButton(
          label: label('makePlan'),
          onPressed: action(
            'makePlan',
            _makePlan,
            enabled: _selected.length == _exercisesPerPlan,
          ),
        ),
      ],
      children: [
        PlaceholderNotice(s('prescriptionStub')),
        MultiChoicePills<String>(
          options: mockExercises,
          selected: _selected,
          labelOf: (exercise) =>
              s('exercise${mockExercises.indexOf(exercise)}'),
          onChanged: busy
              ? null
              : (selection) {
                  if (selection.length <= _exercisesPerPlan) {
                    setState(() => _selected = selection);
                  }
                },
        ),
        Text(
          format('exercisesSelected', {'count': _selected.length}),
          style: text.bodySmall,
        ),
        Form(
          key: _form,
          child: LabeledTextField(
            label: s('dose'),
            controller: _dose,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            enabled: !busy,
            validator: (value) {
              final dose = int.tryParse(value ?? '') ?? 0;
              return dose < 1 || dose > 20 ? s('doseRange') : null;
            },
          ),
        ),
      ],
    );
  }
}

class PlanTransferPage extends ConsumerStatefulWidget {
  const PlanTransferPage({super.key, required this.participantId});

  final String participantId;

  @override
  ConsumerState<PlanTransferPage> createState() => _PlanTransferPageState();
}

class _PlanTransferPageState extends ConsumerState<PlanTransferPage>
    with SetupActions {
  @override
  Widget build(BuildContext context) {
    return ActionPage(
      title: s('transfer'),
      error: error,
      onBack: () => context.go(_readyRoute),
      backLabel: s('back'),
      actions: [
        TransferButtons(
          sending: true,
          qrLabel: label('showQr'),
          fileLabel: label('exportFile'),
          onQr: action(
            'showQr',
            () => send(
              qr: true,
              envelope: () async => service.planEnvelope(widget.participantId),
            ),
          ),
          onFile: action(
            'exportFile',
            () => send(
              qr: false,
              envelope: () async => service.planEnvelope(widget.participantId),
            ),
          ),
        ),
      ],
      children: [
        Text(widget.participantId, style: AppTypography.participantCode),
        InfoNotice(s('planTransferHelp'), icon: LucideIcons.send),
      ],
    );
  }
}
