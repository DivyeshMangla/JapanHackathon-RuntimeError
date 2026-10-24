import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/page_list.dart';
import '../../study/domain/participant_record.dart';
import '../../study/presentation/consent_fields.dart';
import '../../study/presentation/controllers/study_controllers.dart';
import '../domain/participant_study.dart';
import 'controllers/caseload_controllers.dart';
import 'participant_detail_screen.dart';
import 'study_record_fields.dart';
import 'withdrawal_section.dart';

/// Baseline assessment forms for one participant: consent, intervention
/// start, orientation, and the Demographic and Clinical Information Form.
class StudyRecordScreen extends ConsumerWidget {
  const StudyRecordScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final study = ref.watch(participantStudyProvider(patientId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.studyRecordTitle)),
      body: AsyncView(
        value: study,
        data: (study) => study == null
            ? const ParticipantNotFound()
            : _StudyRecordForm(study: study),
      ),
    );
  }
}

class _StudyRecordForm extends ConsumerStatefulWidget {
  const _StudyRecordForm({required this.study});

  final ParticipantStudy study;

  @override
  ConsumerState<_StudyRecordForm> createState() => _StudyRecordFormState();
}

class _StudyRecordFormState extends ConsumerState<_StudyRecordForm> {
  final _form = GlobalKey<FormState>();
  late final ParticipantRecord _initial = widget.study.record;
  late final DemographicsDraft _demographics = DemographicsDraft.from(
    _initial.demographics,
  );
  late final ClinicalDraft _clinical = ClinicalDraft.from(_initial.clinical);
  late bool _infoSheet = _initial.infoSheetProvided;
  late DateTime? _consentOn = _initial.consentSignedOn;
  late DateTime _start = _initial.interventionStart;
  late DateTime? _orientationOn = _initial.orientationOn;
  bool _attempted = false;
  bool _saving = false;

  @override
  void dispose() {
    _demographics.dispose();
    _clinical.dispose();
    super.dispose();
  }

  bool get _choicesComplete =>
      _infoSheet &&
      _consentOn != null &&
      _demographics.choicesComplete &&
      _clinical.choicesComplete;

  Future<void> _save() async {
    final fieldsValid = _form.currentState!.validate();
    if (!fieldsValid || !_choicesComplete) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    final l10n = context.l10n;
    final saved = await runWithFailureMessage(
      context,
      () => ref
          .read(studyRecordActionsProvider)
          .save(
            _initial.copyWith(
              infoSheetProvided: _infoSheet,
              consentSignedOn: _consentOn,
              interventionStart: _start,
              orientationOn: _orientationOn,
              demographics: _demographics.build(),
              clinical: _clinical.build(),
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.studyRecordSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = dateOnly(DateTime.now());
    final summary = widget.study.summary;
    return Form(
      key: _form,
      child: PageList(
        children: [
          Text(summary.code, style: AppTypography.participantCode),
          Text(
            summary.patient.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.consentSection),
          ConsentFields(
            infoSheet: _infoSheet,
            consentOn: _consentOn,
            showMissing: _attempted,
            onInfoSheet: (v) => setState(() => _infoSheet = v),
            onConsentOn: (d) => setState(() => _consentOn = d),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.interventionSection),
          DateField(
            label: l10n.interventionStartLabel,
            value: _start,
            firstDate: DateTime(today.year - 2),
            lastDate: addDays(today, 365),
            onChanged: (d) => setState(() => _start = d),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.interventionStartHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          DateField(
            label: l10n.orientationLabel,
            value: _orientationOn,
            firstDate: DateTime(today.year - 2),
            lastDate: today,
            onChanged: (d) => setState(() => _orientationOn = d),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.demographicsSection),
          DemographicsFields(
            draft: _demographics,
            showMissing: _attempted,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionLabel(l10n.clinicalSection),
          ClinicalFields(
            draft: _clinical,
            showMissing: _attempted,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_attempted && !_choicesComplete)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                l10n.studyRecordIncomplete,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
          PrimaryButton(
            label: _saving ? l10n.saving : l10n.saveStudyRecord,
            icon: LucideIcons.check,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: AppSpacing.xl),
          WithdrawalSection(record: widget.study.record),
        ],
      ),
    );
  }
}
