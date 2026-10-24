import 'dart:typed_data';

import 'recording.dart';

abstract interface class RecordingRepository {
  /// Newest first.
  Future<List<Recording>> forPatient(String patientId);

  /// Every recording, for export and storage migration.
  Future<List<Recording>> all();

  /// Stores [recording] together with the WAV file at [wavPath].
  Future<void> save(Recording recording, {required String wavPath});

  /// The recorded WAV audio.
  Future<Uint8List> audio(String recordingId);
}
