import 'package:record/record.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';

/// Thin wrapper over the `record` plugin fixed to the study format:
/// uncompressed WAV, 44.1 kHz, mono.
class VoiceRecorder {
  VoiceRecorder() : _recorder = AudioRecorder();

  static const config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 44100,
    numChannels: 1,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
  );

  final AudioRecorder _recorder;

  /// Prompts for microphone access the first time.
  Future<bool> ensurePermission() =>
      guard(_recorder.hasPermission, RecordingFailure.new);

  Future<void> start(String path) =>
      guard(() => _recorder.start(config, path: path), RecordingFailure.new);

  /// Returns the path of the finished file.
  Future<String?> stop() => guard(_recorder.stop, RecordingFailure.new);

  Future<void> cancel() => _recorder.cancel();

  /// Input level in dBFS (roughly -60 silent to 0 loudest).
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      .map((a) => a.current);

  Future<void> dispose() => _recorder.dispose();
}
