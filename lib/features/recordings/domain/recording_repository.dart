import 'recording.dart';

abstract interface class RecordingRepository {
  /// Newest first.
  Future<List<Recording>> forPatient(String patientId);

  /// Every recording, for export and storage migration.
  Future<List<Recording>> all();

  Future<void> save(Recording recording);
}
