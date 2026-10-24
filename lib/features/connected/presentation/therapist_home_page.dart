import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/ink_card.dart';
import '../data/connected_service.dart';
import '../domain/connected_models.dart';
import 'connected_actions.dart';
import 'home_header_actions.dart';
import 'therapist_patient_page.dart';

/// The therapist's caseload, patients needing a consent review first.
class TherapistHomePage extends StatelessWidget {
  const TherapistHomePage({super.key, required this.service});

  final ConnectedService service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final syncFailure = service.syncFailure;
    final patients = [...service.patients]
      ..sort((a, b) {
        final review =
            (b.consentStatus == ConsentStatus.pending ? 1 : 0) -
            (a.consentStatus == ConsentStatus.pending ? 1 : 0);
        return review != 0 ? review : a.name.compareTo(b.name);
      });
    return ActionPage(
      title: l10n.connectedGreeting(service.user!.name),
      intro: l10n.connectedTherapistIntro,
      headerAction: HomeHeaderActions(service: service),
      error: syncFailure == null
          ? null
          : l10n.connectedFailureMessage(syncFailure),
      children: [
        if (patients.isEmpty)
          EmptyState(
            icon: LucideIcons.users,
            title: l10n.connectedNoPatientsTitle,
            message: l10n.connectedNoPatientsMessage,
          ),
        for (final patient in patients)
          _PatientCard(
            patient: patient,
            // Patient records are never cached, so they open only online.
            onTap: service.offline
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TherapistPatientPage(
                        service: service,
                        patientId: patient.id,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.onTap});

  final PatientSummary patient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final status = switch (patient.consentStatus) {
      ConsentStatus.missing => l10n.connectedConsentMissing,
      ConsentStatus.pending => l10n.connectedConsentPending,
      ConsentStatus.approved => l10n.connectedConsentApproved,
    };
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkCard(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(LucideIcons.userRound, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name, style: text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.connectedActiveDays(patient.activeDays),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusPill(
              label: status,
              highlighted: patient.consentStatus == ConsentStatus.pending,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: AppColors.wash,
            ),
          ],
        ),
      ),
    );
  }
}
