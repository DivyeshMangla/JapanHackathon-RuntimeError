import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../capture_quality/data/sensor_sources.dart';
import '../../../capture_quality/domain/audio_analyzer.dart';
import '../../../capture_quality/domain/motion_analyzer.dart';
import '../../../capture_quality/domain/noise_profiler.dart';
import '../../domain/live_audio_pipeline.dart';

/// The screen redraws at about 15 frames a second; sensors arrive faster.
const _frameInterval = Duration(milliseconds: 66);

enum MonitorStatus { idle, listening, denied, failed }

class AudioMonitorState {
  const AudioMonitorState({
    this.status = MonitorStatus.idle,
    this.rawWave = const [],
    this.cleanWave = const [],
    this.levelHistory = const [],
    this.cleanLevelHistory = const [],
    this.floorHistory = const [],
    this.quality,
    this.cleaning,
    this.spectrum,
    this.noiseReport,
    this.voiced = false,
  });

  final MonitorStatus status;

  /// The last ~1.5 s of waveform, as min/max columns.
  final List<WaveColumn> rawWave;
  final List<WaveColumn> cleanWave;

  /// The last ~10 s of block levels (dBFS) and noise floor estimates.
  final List<double> levelHistory;
  final List<double> cleanLevelHistory;
  final List<double> floorHistory;
  final AudioQuality? quality;
  final CleaningStats? cleaning;
  final SpectrumView? spectrum;
  final NoiseReport? noiseReport;
  final bool voiced;
}

final audioMonitorProvider =
    NotifierProvider.autoDispose<AudioMonitorController, AudioMonitorState>(
      AudioMonitorController.new,
    );

/// Streams the microphone through [LiveAudioPipeline] for as long as the
/// screen is open.
class AudioMonitorController extends Notifier<AudioMonitorState> {
  static const _waveBlocks = 64;
  static const _historyBlocks = 430;

  final _microphone = MicrophoneStream();
  late LiveAudioPipeline _pipeline;
  StreamSubscription<Object?>? _audio;
  Timer? _frames;
  final _raw = <WaveColumn>[];
  final _clean = <WaveColumn>[];
  final _levels = <double>[];
  final _cleanLevels = <double>[];
  final _floors = <double>[];
  bool _voiced = false;

  @override
  AudioMonitorState build() {
    // Listening starts as soon as the screen opens and stops when it closes.
    Future.microtask(start);
    ref.onDispose(() {
      unawaited(_audio?.cancel());
      _frames?.cancel();
      unawaited(_microphone.dispose());
    });
    return const AudioMonitorState();
  }

  Future<void> start() async {
    try {
      if (!await _microphone.ensurePermission()) {
        state = const AudioMonitorState(status: MonitorStatus.denied);
        return;
      }
      _pipeline = LiveAudioPipeline(sampleRate: MicrophoneStream.sampleRate);
      for (final list in [_raw, _clean, _levels, _cleanLevels, _floors]) {
        list.clear();
      }
      final stream = await _microphone.start();
      _audio = stream.listen(
        (bytes) => _consume(pcm16ToSamples(bytes)),
        onError: (Object _) => _fail(),
      );
      _frames = Timer.periodic(_frameInterval, (_) => _publish());
      state = const AudioMonitorState(status: MonitorStatus.listening);
    } on AppFailure {
      _fail();
    }
  }

  void _consume(Float32List samples) {
    const waveColumns = _waveBlocks * LiveAudioPipeline.columnsPerBlock;
    for (final frame in _pipeline.add(samples)) {
      _append(_raw, frame.rawColumns, waveColumns);
      _append(_clean, frame.cleanColumns, waveColumns);
      _append(_levels, [frame.levelDb], _historyBlocks);
      _append(_cleanLevels, [frame.cleanLevelDb], _historyBlocks);
      _append(_floors, [frame.noiseFloorDb], _historyBlocks);
      _voiced = frame.voiced;
    }
  }

  void _publish() => state = AudioMonitorState(
    status: MonitorStatus.listening,
    rawWave: List.unmodifiable(_raw),
    cleanWave: List.unmodifiable(_clean),
    levelHistory: List.unmodifiable(_levels),
    cleanLevelHistory: List.unmodifiable(_cleanLevels),
    floorHistory: List.unmodifiable(_floors),
    quality: _pipeline.quality,
    cleaning: _pipeline.cleaning,
    spectrum: _pipeline.spectrum,
    noiseReport: _pipeline.noiseReport,
    voiced: _voiced,
  );

  void _fail() {
    _frames?.cancel();
    state = const AudioMonitorState(status: MonitorStatus.failed);
  }

  static void _append<T>(List<T> target, List<T> values, int limit) {
    target.addAll(values);
    if (target.length > limit) target.removeRange(0, target.length - limit);
  }
}

class MotionState {
  const MotionState({
    this.reading,
    this.gyroHistory = const [],
    this.reference,
    this.available = true,
  });

  final MotionReading? reading;

  /// Gyroscope RMS over the last ~5 s, one point per frame.
  final List<double> gyroHistory;

  /// Tilt captured with "Set reference", to compare against.
  final Tilt? reference;
  final bool available;

  MotionState copyWith({
    MotionReading? reading,
    List<double>? gyroHistory,
    Tilt? reference,
    bool? available,
  }) => MotionState(
    reading: reading ?? this.reading,
    gyroHistory: gyroHistory ?? this.gyroHistory,
    reference: reference ?? this.reference,
    available: available ?? this.available,
  );
}

final motionMonitorProvider =
    NotifierProvider.autoDispose<MotionMonitorController, MotionState>(
      MotionMonitorController.new,
    );

class MotionMonitorController extends Notifier<MotionState> {
  static const _historyFrames = 75;

  @override
  MotionState build() {
    const sensors = MotionSensors();
    final analyzer = MotionAnalyzer(
      windowSamples: MotionSensors.samplesPerSecond,
    );
    final history = <double>[];
    void unavailable(Object _) => state = state.copyWith(available: false);

    final subscriptions = [
      sensors.gyroscope().listen(analyzer.addGyro, onError: unavailable),
      sensors.accelerometer().listen(analyzer.addAccel, onError: unavailable),
      sensors.userAccelerometer().listen(
        analyzer.addUserAccel,
        onError: unavailable,
      ),
    ];
    final frames = Timer.periodic(_frameInterval, (_) {
      final reading = analyzer.reading;
      history.add(reading.gyroRms);
      if (history.length > _historyFrames) history.removeAt(0);
      state = state.copyWith(
        reading: reading,
        gyroHistory: List.unmodifiable(history),
      );
    });
    ref.onDispose(() {
      frames.cancel();
      for (final s in subscriptions) {
        unawaited(s.cancel());
      }
    });
    return const MotionState();
  }

  void setReference() {
    final tilt = state.reading?.tilt;
    if (tilt != null) state = state.copyWith(reference: tilt);
  }
}

/// Null while the device has no proximity sensor.
final proximityProvider = StreamProvider.autoDispose<bool?>((ref) async* {
  const sensors = MotionSensors();
  if (!await sensors.proximityAvailable()) {
    yield null;
    return;
  }
  yield false;
  yield* sensors.proximityNear();
});
