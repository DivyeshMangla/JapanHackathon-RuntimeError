import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/backend_client.dart';
import '../domain/recording.dart';
import '../domain/recording_repository.dart';

/// Voice samples on the care service. Audio is uploaded as a WAV when a take
/// is kept and fetched again, with an audit entry on the server, to play it.
class BackendRecordingRepository implements RecordingRepository {
  BackendRecordingRepository(this._client);

  final BackendClient _client;

  @override
  Future<List<Recording>> forPatient(String patientId) async {
    final response = await _client.get('/patients/$patientId/samples');
    return response.objects('samples').map(Recording.fromMap).toList();
  }

  @override
  Future<List<Recording>> all() async {
    final response = await _client.get('/samples');
    return response.objects('samples').map(Recording.fromMap).toList();
  }

  @override
  Future<void> save(Recording recording, {required String wavPath}) async {
    final Uint8List wav;
    try {
      wav = await File(wavPath).readAsBytes();
    } on IOException catch (error) {
      throw RecordingFailure(error);
    }
    await _client.put(
      '/patients/${recording.patientId}/samples/${recording.id}',
      body: {'meta': recording.toMap(), 'audio': base64Encode(wav)},
    );
  }

  @override
  Future<Uint8List> audio(String recordingId) =>
      _client.getBytes('/samples/$recordingId/audio');
}
