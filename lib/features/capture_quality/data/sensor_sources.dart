import 'dart:typed_data';

import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:record/record.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../domain/motion_analyzer.dart';

/// Live microphone audio as raw 16-bit PCM, analysed in memory and never
/// written to disk.
class MicrophoneStream {
  MicrophoneStream() : _recorder = AudioRecorder();

  static const sampleRate = 44100;

  static const _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: 1,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
  );

  final AudioRecorder _recorder;

  Future<bool> ensurePermission() =>
      guard(_recorder.hasPermission, SensorFailure.new);

  Future<Stream<Uint8List>> start() =>
      guard(() => _recorder.startStream(_config), SensorFailure.new);

  Future<void> stop() => guard(_recorder.stop, SensorFailure.new);

  Future<void> dispose() => _recorder.dispose();
}

/// Motion and proximity sensor streams, mapped to domain types.
class MotionSensors {
  const MotionSensors();

  /// 50 Hz: well under Android's 200 Hz cap, which needs a special
  /// permission, and fast enough for hand movement.
  static const interval = SensorInterval.gameInterval;

  static int get samplesPerSecond =>
      Duration.millisecondsPerSecond ~/ interval.inMilliseconds;

  Stream<Vector3> gyroscope() => gyroscopeEventStream(
    samplingPeriod: interval,
  ).map((e) => Vector3(e.x, e.y, e.z));

  Stream<Vector3> accelerometer() => accelerometerEventStream(
    samplingPeriod: interval,
  ).map((e) => Vector3(e.x, e.y, e.z));

  Stream<Vector3> userAccelerometer() => userAccelerometerEventStream(
    samplingPeriod: interval,
  ).map((e) => Vector3(e.x, e.y, e.z));

  Future<bool> proximityAvailable() =>
      guard(ProximitySensor.isProximitySensorAvailable, SensorFailure.new);

  /// True while something is within a few centimetres of the screen.
  Stream<bool> proximityNear() => ProximitySensor.events.map((e) => e > 0);
}
