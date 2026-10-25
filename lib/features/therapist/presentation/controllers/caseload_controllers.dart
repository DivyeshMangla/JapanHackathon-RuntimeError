import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../recordings/domain/recording.dart';
import '../../../recordings/presentation/controllers/recording_controllers.dart';
import '../../domain/participant_summary.dart';

/// Builds the summary for one patient.
final participantSummaryProvider =
    FutureProvider.family<ParticipantSummary, String>((ref, patientId) async {
      final patient = await ref.watch(userByIdProvider(patientId).future);
      if (patient == null) throw StateError('Unknown patient $patientId');
      final recordings = await ref.watch(
        patientRecordingsProvider(patientId).future,
      );
      return ParticipantSummary(
        patient: patient,
        recordings: recordings,
        probeDue: await ref.watch(probeDueProvider(patientId).future),
      );
    });

/// The signed-in therapist's patients, ordered by participant code. Disposed
/// with the screens that show it, so a later sign-in builds it afresh rather
/// than refreshing a previous session's caseload in the middle of a frame.
final caseloadProvider = FutureProvider.autoDispose<List<ParticipantSummary>>((
  ref,
) async {
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
final caseloadParticipantProvider = FutureProvider.autoDispose
    .family<ParticipantSummary?, String>((ref, patientId) async {
      final caseload = await ref.watch(caseloadProvider.future);
      return caseload.where((p) => p.patient.id == patientId).firstOrNull;
    });

/// Every recording across the caseload, newest first, with its patient.
final caseloadRecordingsProvider =
    FutureProvider.autoDispose<List<(ParticipantSummary, Recording)>>((
      ref,
    ) async {
      final caseload = await ref.watch(caseloadProvider.future);
      return [
        for (final participant in caseload)
          for (final recording in participant.recordings)
            (participant, recording),
      ]..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    });
