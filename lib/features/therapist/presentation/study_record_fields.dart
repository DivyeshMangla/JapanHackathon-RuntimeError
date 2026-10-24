import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/date_field.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../study/domain/participant_record.dart';

/// Editable state of the demographic form, built into [Demographics] once
/// every required answer is present.
class DemographicsDraft {
  DemographicsDraft.from(Demographics? saved)
    : age = TextEditingController(text: saved?.ageYears.toString() ?? ''),
      occupation = TextEditingController(text: saved?.occupation ?? ''),
      language = TextEditingController(text: saved?.primaryLanguage ?? ''),
      gender = saved?.gender,
      education = saved?.education,
      voiceUse = saved?.voiceUse;

  final TextEditingController age;
  final TextEditingController occupation;
  final TextEditingController language;
  Gender? gender;
  EducationLevel? education;
  VoiceUseLevel? voiceUse;

  bool get choicesComplete =>
      gender != null && education != null && voiceUse != null;

  /// Call only after the enclosing form validated and [choicesComplete].
  Demographics build() => Demographics(
    ageYears: int.parse(age.text.trim()),
    gender: gender!,
    education: education!,
    occupation: occupation.text.trim(),
    voiceUse: voiceUse!,
    primaryLanguage: language.text.trim(),
  );

  void dispose() {
    age.dispose();
    occupation.dispose();
    language.dispose();
  }
}

/// Editable state of the clinical form.
class ClinicalDraft {
  ClinicalDraft.from(ClinicalDetails? saved)
    : diagnosis = TextEditingController(text: saved?.diagnosis ?? ''),
      months = TextEditingController(
        text: saved?.symptomMonths.toString() ?? '',
      ),
      clinicSessions = TextEditingController(
        text: saved?.clinicSessionsPerWeek?.toString() ?? '',
      ),
      otherConditions = TextEditingController(
        text: saved?.otherConditions ?? '',
      ),
      smoking = saved?.smoking,
      laryngoscopyOn = saved?.laryngoscopyOn,
      therapyStartedOn = saved?.therapyStartedOn;

  final TextEditingController diagnosis;
  final TextEditingController months;
  final TextEditingController clinicSessions;
  final TextEditingController otherConditions;
  SmokingStatus? smoking;
  DateTime? laryngoscopyOn;
  DateTime? therapyStartedOn;

  bool get choicesComplete => smoking != null;

  /// Call only after the enclosing form validated and [choicesComplete].
  ClinicalDetails build() => ClinicalDetails(
    diagnosis: diagnosis.text.trim(),
    symptomMonths: int.parse(months.text.trim()),
    smoking: smoking!,
    laryngoscopyOn: laryngoscopyOn,
    therapyStartedOn: therapyStartedOn,
    clinicSessionsPerWeek: int.tryParse(clinicSessions.text.trim()),
    otherConditions: otherConditions.text.trim(),
  );

  void dispose() {
    diagnosis.dispose();
    months.dispose();
    clinicSessions.dispose();
    otherConditions.dispose();
  }
}

final _digitsOnly = [FilteringTextInputFormatter.digitsOnly];

/// Validator for a whole number in [min, max]; empty passes when optional.
FormFieldValidator<String> _wholeNumber(
  String message, {
  required int min,
  required int max,
  bool optional = false,
}) => (value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return optional ? null : message;
  final number = int.tryParse(text);
  return number == null || number < min || number > max ? message : null;
};

class DemographicsFields extends StatelessWidget {
  const DemographicsFields({
    super.key,
    required this.draft,
    required this.showMissing,
    required this.onChanged,
  });

  final DemographicsDraft draft;
  final bool showMissing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? l10n.fieldRequired : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledTextField(
          label: l10n.ageLabel,
          controller: draft.age,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          validator: _wholeNumber(l10n.ageInvalid, min: 1, max: 120),
        ),
        const SizedBox(height: AppSpacing.md),
        _ChoiceField<Gender>(
          label: l10n.genderTitle,
          options: Gender.values,
          selected: draft.gender,
          labelOf: l10n.genderLabel,
          showMissing: showMissing,
          onSelected: (v) {
            draft.gender = v;
            onChanged();
          },
        ),
        _ChoiceField<EducationLevel>(
          label: l10n.educationTitle,
          options: EducationLevel.values,
          selected: draft.education,
          labelOf: l10n.educationLabel,
          showMissing: showMissing,
          onSelected: (v) {
            draft.education = v;
            onChanged();
          },
        ),
        LabeledTextField(
          label: l10n.occupationLabel,
          controller: draft.occupation,
          validator: required,
        ),
        const SizedBox(height: AppSpacing.md),
        _ChoiceField<VoiceUseLevel>(
          label: l10n.voiceUseTitle,
          options: VoiceUseLevel.values,
          selected: draft.voiceUse,
          labelOf: l10n.voiceUseLabel,
          showMissing: showMissing,
          onSelected: (v) {
            draft.voiceUse = v;
            onChanged();
          },
        ),
        LabeledTextField(
          label: l10n.languageLabel,
          controller: draft.language,
          validator: required,
        ),
      ],
    );
  }
}

class ClinicalFields extends StatelessWidget {
  const ClinicalFields({
    super.key,
    required this.draft,
    required this.showMissing,
    required this.onChanged,
  });

  final ClinicalDraft draft;
  final bool showMissing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = dateOnly(DateTime.now());
    final earliest = DateTime(today.year - 20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledTextField(
          label: l10n.diagnosisLabel,
          hint: l10n.diagnosisHint,
          controller: draft.diagnosis,
          validator: (v) =>
              (v ?? '').trim().isEmpty ? l10n.fieldRequired : null,
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.symptomMonthsLabel,
          controller: draft.months,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          validator: _wholeNumber(l10n.monthsInvalid, min: 0, max: 600),
        ),
        const SizedBox(height: AppSpacing.md),
        _ChoiceField<SmokingStatus>(
          label: l10n.smokingTitle,
          options: SmokingStatus.values,
          selected: draft.smoking,
          labelOf: l10n.smokingLabel,
          showMissing: showMissing,
          onSelected: (v) {
            draft.smoking = v;
            onChanged();
          },
        ),
        DateField(
          label: l10n.laryngoscopyLabel,
          value: draft.laryngoscopyOn,
          firstDate: earliest,
          lastDate: today,
          onChanged: (d) {
            draft.laryngoscopyOn = d;
            onChanged();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        DateField(
          label: l10n.therapyStartLabel,
          value: draft.therapyStartedOn,
          firstDate: earliest,
          lastDate: today,
          onChanged: (d) {
            draft.therapyStartedOn = d;
            onChanged();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.clinicSessionsLabel,
          controller: draft.clinicSessions,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          validator: _wholeNumber(
            l10n.sessionsInvalid,
            min: 0,
            max: 14,
            optional: true,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LabeledTextField(
          label: l10n.otherConditionsLabel,
          hint: l10n.otherConditionsHint,
          controller: draft.otherConditions,
          maxLines: 3,
        ),
      ],
    );
  }
}

/// A labelled single-choice pill row with an inline message while nothing
/// is chosen and the form has been submitted.
class _ChoiceField<T extends Object> extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.showMissing,
    required this.onSelected,
  });

  final String label;
  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final bool showMissing;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: text.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          ChoicePills<T?>(
            options: options,
            selected: selected,
            labelOf: (v) => labelOf(v!),
            onSelected: (v) => onSelected(v!),
          ),
          if (showMissing && selected == null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.chooseOne,
              style: text.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}
