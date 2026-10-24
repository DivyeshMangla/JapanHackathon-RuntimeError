import 'package:flutter/material.dart';

import 'patient_consent_pages.dart';
import 'patient_start_pages.dart';
import 'role_page.dart';
import 'therapist_access_pages.dart';
import 'therapist_patient_pages.dart';

/// Picks the page for a setup route. [page] is a setup stage name or one of
/// the therapist's own pages; [participantId] identifies the patient for the
/// per-patient pages.
class SetupScreen extends StatelessWidget {
  const SetupScreen({required this.page, this.participantId, super.key});

  final String page;
  final String? participantId;

  @override
  Widget build(BuildContext context) {
    return switch (page) {
      'unset' => const RolePage(),
      'needsSignup' => const TherapistSignupPage(),
      'needsPin' => const PinSetupPage(),
      'needsKeys' => const KeyGenerationPage(),
      'unlock' => const UnlockPage(),
      'ready' => const TherapistReadyPage(),
      'joinCode' => const JoinCodePage(),
      'patient' => ConsentReviewPage(participantId: participantId!),
      'forms' => PatientFormsPage(participantId: participantId!),
      'prescribe' => PrescribePage(participantId: participantId!),
      'transfer' => PlanTransferPage(participantId: participantId!),
      'needsJoin' => const JoinTherapistPage(),
      'language' => const LanguagePage(),
      'information' => const StudyInformationPage(),
      'consent' => const ConsentPage(),
      'signature' => const SignaturePage(),
      'sendConsent' => const SendConsentPage(),
      'awaitingPlan' => const AwaitingPlanPage(),
      'orientation' => const OrientationPage(),
      'baseline' => const BaselinePage(),
      'active' => const SetupCompletePage(),
      _ => const SizedBox.shrink(),
    };
  }
}
