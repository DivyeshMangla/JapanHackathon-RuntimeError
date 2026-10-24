import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../exercises/presentation/controllers/exercise_controllers.dart';
import '../../../questionnaires/presentation/controllers/questionnaire_controllers.dart';
import '../../../recordings/domain/recording.dart';
import '../../../recordings/presentation/controllers/recording_controllers.dart';
import '../../../settings/presentation/controllers/study_settings_controller.dart';
import '../../../study/domain/participant_status.dart';
import '../../../study/presentation/controllers/study_controllers.dart';
import '../../domain/participant_study.dart';
import '../../domain/participant_summary.dart';

/// Builds the summary for one patient under the current study settings.
final participantSummaryProvider =
    FutureProvider.family<ParticipantSummary, String>((ref, patientId) async {
      final patient = await ref.watch(userByIdProvider(patientId).future);
      if (patient == null) throw StateError('Unknown patient $patientId');
      final settings = await ref.watch(studySettingsProvider.future);
      final activity = await ref.watch(
        patientActivityProvider(patientId).future,
      );
      final recordings = await ref.watch(
        patientRecordingsProvider(patientId).future,
      );
      final probe = await ref.watch(probeOutcomeProvider(patientId).future);
      final low = activity.isBelow(settings.adherenceThreshold);
      return ParticipantSummary(
        patient: patient,
        activity: activity,
        recordings: recordings,
        lowAdherence: low,
        status: ParticipantStatus.from(
          highAdherence: activity.recentRate != null && !low,
          probe: probe,
        ),
        probeDue: await ref.watch(probeDueProvider(patientId).future),
      );
    });

/// The signed-in therapist's patients, ordered by participant code.
final caseloadProvider = FutureProvider<List<ParticipantSummary>>((ref) async {
  final therapist = ref.watch(currentUserProvider);
  final patients = await ref
      .watch(userRepositoryProvider)
      .patientsOf(therapist.id);
  return Future.wait([
    for (final patient in patients)
      ref.watch(participantSummaryProvider(patient.id).future),
  ]);
});

/// Looks up one participant, but only if they are on the signed-in
/// therapist's caseload. Null otherwise, so a therapist cannot open another
/// therapist's patient by URL.
final caseloadParticipantProvider =
    FutureProvider.family<ParticipantSummary?, String>((ref, patientId) async {
      final caseload = await ref.watch(caseloadProvider.future);
      return caseload.where((p) => p.patient.id == patientId).firstOrNull;
    });

/// Every recording across the caseload, newest first, with its patient.
final caseloadRecordingsProvider =
    FutureProvider<List<(ParticipantSummary, Recording)>>((ref) async {
      final caseload = await ref.watch(caseloadProvider.future);
      return [
        for (final participant in caseload)
          for (final recording in participant.recordings)
            (participant, recording),
      ]..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    });

/// Study record, outcomes, questionnaires and monitoring for one caseload
/// participant, or null when they are not on the signed-in therapist's
/// caseload.
final participantStudyProvider =
    FutureProvider.family<ParticipantStudy?, String>((ref, patientId) async {
      final summary = await ref.watch(
        caseloadParticipantProvider(patientId).future,
      );
      if (summary == null) return null;
      return ParticipantStudy(
        summary: summary,
        record: await ref.watch(participantRecordProvider(patientId).future),
        outcome: await ref.watch(interventionOutcomeProvider(patientId).future),
        questionnaires: await ref.watch(
          questionnaireHistoryProvider(patientId).future,
        ),
        monitoring: await ref.watch(
          monitoringEntriesProvider(patientId).future,
        ),
        voiceDiary: await ref.watch(voiceDiaryProvider(patientId).future),
      );
    });
