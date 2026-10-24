import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/presentation/controllers/study_settings_controller.dart';
import '../../../study/domain/participant_status.dart';
import '../../../study/presentation/controllers/study_controllers.dart';
import '../../data/recording_repository_providers.dart';
import '../../domain/probe_schedule.dart';
import '../../domain/recording.dart';

final patientRecordingsProvider =
    FutureProvider.family<List<Recording>, String>(
      (ref, patientId) =>
          ref.watch(recordingRepositoryProvider).forPatient(patientId),
    );

/// When the patient's next probe is due under the current study settings.
/// A withdrawn participant is not asked for any more.
final probeDueProvider = FutureProvider.family<ProbeDue, String>((
  ref,
  patientId,
) async {
  final record = await ref.watch(participantRecordProvider(patientId).future);
  final recordings = await ref.watch(
    patientRecordingsProvider(patientId).future,
  );
  final settings = await ref.watch(studySettingsProvider.future);
  if (record.isWithdrawn) {
    return const ProbeDue(nextDue: null, isBaseline: false);
  }
  return ProbeDue.compute(
    enrolledOn: record.interventionStart,
    recordings: recordings,
    settings: settings,
  );
});

final analysisStatusProvider = FutureProvider.family<AnalysisStatus, Recording>(
  (ref, recording) => ref.watch(analysisServiceProvider).statusOf(recording),
);

final probeOutcomeProvider = FutureProvider.family<ProbeOutcome?, String>(
  (ref, patientId) =>
      ref.watch(analysisServiceProvider).probeOutcome(patientId),
);
