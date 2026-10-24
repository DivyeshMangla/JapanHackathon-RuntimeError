import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/date_field.dart';

/// Participant Information Sheet and Written Consent Form, recorded at
/// enrolment and editable in the study record.
class ConsentFields extends StatelessWidget {
  const ConsentFields({
    super.key,
    required this.infoSheet,
    required this.consentOn,
    required this.showMissing,
    required this.onInfoSheet,
    required this.onConsentOn,
  });

  final bool infoSheet;
  final DateTime? consentOn;
  final bool showMissing;
  final ValueChanged<bool> onInfoSheet;
  final ValueChanged<DateTime> onConsentOn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final today = dateOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: infoSheet,
          onChanged: (v) => onInfoSheet(v ?? false),
          title: Text(l10n.infoSheetProvided, style: text.bodyLarge),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (showMissing && !infoSheet)
          Text(
            l10n.infoSheetRequired,
            style: text.bodySmall?.copyWith(color: AppColors.error),
          ),
        const SizedBox(height: AppSpacing.sm),
        DateField(
          label: l10n.consentSignedLabel,
          value: consentOn,
          firstDate: DateTime(today.year - 2),
          lastDate: today,
          onChanged: onConsentOn,
          errorText: showMissing && consentOn == null
              ? l10n.dateRequired
              : null,
        ),
      ],
    );
  }
}
