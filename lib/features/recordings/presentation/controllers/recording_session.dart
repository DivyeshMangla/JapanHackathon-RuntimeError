import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../auth/domain/user.dart';
import '../../../capture_quality/data/sensor_sources.dart';
import '../../../capture_quality/data/take_quality_checker.dart';
import '../../../capture_quality/domain/motion_analyzer.dart';
import '../../../capture_quality/domain/take_quality.dart';
import '../../../usage/domain/usage_event.dart';
import '../../../usage/presentation/controllers/usage_controllers.dart';
import '../../data/recording_repository_providers.dart';
import '../../data/voice_recorder.dart';
import '../../domain/probe_protocol.dart';
import '../../domain/recording.dart';
import 'playback_controller.dart';
import 'recording_controllers.dart';

enum RecordingStage {
  setup,

  /// A probe take is next and the patient has not started it yet.
  ready,
  recording,
  review,
  saving,
  probeComplete,
}

class RecordingSessionState {
  const RecordingSessionState({
    this.stage = RecordingStage.setup,
    this.kind = RecordingKind.practice,
    this.practiceTask = RecordingTask.sustainedPhonation,
    this.probeIndex = 0,
    this.probeType = RecordingType.baseline,
    this.probeSessionId,
    this.elapsed = Duration.zero,
    this.leadInDone = false,
    this.level = 0,
    this.draftPath,
    this.microphoneDenied = false,
    this.failure,
    this.quality,
    this.checkingQuality = false,
  });

  final RecordingStage stage;
  final RecordingKind kind;
  final RecordingTask practiceTask;

  /// Position in [ProbeProtocol.takes] during a probe session.
  final int probeIndex;
  final RecordingType probeType;
  final String? probeSessionId;
  final Duration elapsed;

  /// False for the first half second of a take, while the patient waits.
  final bool leadInDone;

  /// Input level normalised to 0..1 for the meter.
  final double level;
  final String? draftPath;

  /// Set when the last start attempt found microphone access refused.
  final bool microphoneDenied;

  /// The last operation's failure, shown once by the screen.
  final AppFailure? failure;

  /// How fit the take under review is for analysis; null while checking or
  /// if the check could not run.
  final TakeQuality? quality;
  final bool checkingQuality;

  bool get isProbe => kind == RecordingKind.probe;

  ({RecordingTask task, int trial, int of}) get probeTake =>
      ProbeProtocol.takes[probeIndex];

  RecordingTask get task => isProbe ? probeTake.task : practiceTask;

  int get trial => isProbe ? probeTake.trial : 1;

  RecordingType get type => isProbe ? probeType : RecordingType.homePractice;

  double get elapsedSec => elapsed.inMilliseconds / 1000;

  RecordingSessionState copyWith({
    RecordingStage? stage,
    RecordingKind? kind,
    RecordingTask? practiceTask,
    int? probeIndex,
    RecordingType? probeType,
    String? probeSessionId,
    Duration? elapsed,
    bool? leadInDone,
    double? level,
    String? draftPath,
    bool microphoneDenied = false,
    AppFailure? failure,
    TakeQuality? quality,
    bool clearQuality = false,
    bool? checkingQuality,
  }) => RecordingSessionState(
    stage: stage ?? this.stage,
    kind: kind ?? this.kind,
    practiceTask: practiceTask ?? this.practiceTask,
    probeIndex: probeIndex ?? this.probeIndex,
    probeType: probeType ?? this.probeType,
    probeSessionId: probeSessionId ?? this.probeSessionId,
    elapsed: elapsed ?? this.elapsed,
    leadInDone: leadInDone ?? this.leadInDone,
    level: level ?? this.level,
    draftPath: draftPath ?? this.draftPath,
    microphoneDenied: microphoneDenied,
    failure: failure,
    quality: clearQuality ? null : quality ?? this.quality,
    checkingQuality: checkingQuality ?? this.checkingQuality,
  );
}

final recordingSessionProvider =
    NotifierProvider.autoDispose<RecordingSession, RecordingSessionState>(
      RecordingSession.new,
    );

/// Drives capture for both kinds of recording. Practice is one free-choice
/// take. A probe session walks the fixed [ProbeProtocol] take by take. Only
/// kept takes become [Recording]s, and they are stored encrypted.
class RecordingSession extends Notifier<RecordingSessionState> {
  static const maxLength = Duration(minutes: 3);

  late final VoiceRecorder _recorder;
  final _stopwatch = Stopwatch();
  Timer? _ticker;
  StreamSubscription<double>? _levels;
  final _motionSubscriptions = <StreamSubscription<Vector3>>[];
  MotionAnalyzer? _motion;
  int _motionTicks = 0;
  int _movingTicks = 0;

  /// Identifies the take a quality check belongs to, so a result that
  /// arrives after a retake or discard is ignored.
  int _take = 0;

  @override
  RecordingSessionState build() {
    _recorder = VoiceRecorder();
    ref.onDispose(() {
      _ticker?.cancel();
      unawaited(_levels?.cancel());
      unawaited(_stopMotion());
      unawaited(_recorder.dispose());
    });
    return const RecordingSessionState();
  }

  void selectPracticeTask(RecordingTask task) =>
      state = state.copyWith(practiceTask: task);

  /// Starts the first practice take.
  Future<void> startPractice() => _reporting(() async {
    state = state.copyWith(kind: RecordingKind.practice);
    await _start();
  });

  /// Begins a probe session at its first take. The first probe a patient
  /// records is their baseline; later ones are follow-ups.
  void beginProbe({required bool baseline}) => state = state.copyWith(
    stage: RecordingStage.ready,
    kind: RecordingKind.probe,
    probeIndex: 0,
    probeType: baseline ? RecordingType.baseline : RecordingType.followUp,
    probeSessionId: const Uuid().v4(),
  );

  Future<void> start() => _reporting(_start);

  Future<void> _start() async {
    if (!await _recorder.ensurePermission()) {
      state = state.copyWith(microphoneDenied: true);
      return;
    }
    await ref.read(playbackProvider.notifier).release();
    final path = await ref.read(recordingFilesProvider).draftPath();
    await _recorder.start(path);

    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_stopwatch.elapsed >= maxLength) {
        unawaited(stop());
      } else {
        _sampleMotion();
        state = state.copyWith(
          elapsed: _stopwatch.elapsed,
          leadInDone: _stopwatch.elapsed >= ProbeProtocol.leadIn,
        );
      }
    });
    _levels = _recorder.levels().listen(
      // Map roughly -50..0 dBFS onto 0..1.
      (db) => state = state.copyWith(level: ((db + 50) / 50).clamp(0, 1)),
    );
    _startMotion();
    _take++;
    state = state.copyWith(
      stage: RecordingStage.recording,
      elapsed: Duration.zero,
      leadInDone: false,
      draftPath: path,
      clearQuality: true,
      checkingQuality: false,
    );
  }

  /// Motion is advisory, so a device without these sensors still records.
  void _startMotion() {
    const sensors = MotionSensors();
    final motion = MotionAnalyzer(
      windowSamples: MotionSensors.samplesPerSecond,
    );
    void unavailable(Object error) {
      AppLogger.warning('Motion sensors unavailable during recording', error);
      _motion = null;
    }

    _motion = motion;
    _motionTicks = 0;
    _movingTicks = 0;
    _motionSubscriptions.addAll([
      sensors.gyroscope().listen(motion.addGyro, onError: unavailable),
      sensors.userAccelerometer().listen(
        motion.addUserAccel,
        onError: unavailable,
      ),
    ]);
  }

  void _sampleMotion() {
    final motion = _motion;
    if (motion == null) return;
    _motionTicks++;
    if (motion.reading.moving) _movingTicks++;
  }

  Future<void> _stopMotion() async {
    for (final subscription in _motionSubscriptions) {
      await subscription.cancel();
    }
    _motionSubscriptions.clear();
  }

  Future<void> stop() => _reporting(_stop);

  Future<void> _stop() async {
    if (state.stage != RecordingStage.recording) return;
    _ticker?.cancel();
    await _levels?.cancel();
    _stopwatch.stop();
    await _stopMotion();
    await _recorder.stop();
    final movingFraction = _motion == null || _motionTicks == 0
        ? null
        : _movingTicks / _motionTicks;
    state = state.copyWith(
      stage: RecordingStage.review,
      elapsed: _stopwatch.elapsed,
      level: 0,
      checkingQuality: true,
    );
    unawaited(_checkQuality(_take, movingFraction));
  }

  /// Measures the take in the background while the patient listens back.
  /// A failed check only hides the quality card; it never blocks saving.
  Future<void> _checkQuality(int take, double? movingFraction) async {
    final path = state.draftPath;
    if (path == null) return;
    TakeQuality? quality;
    try {
      quality = (await ref.read(takeQualityCheckerProvider).check(path))
          .withMotion(movingFraction);
    } on AppFailure catch (failure) {
      AppLogger.warning('Take quality check failed', failure);
    }
    if (!ref.mounted || take != _take || state.stage != RecordingStage.review) {
      return;
    }
    state = state.copyWith(quality: quality, checkingQuality: false);
  }

  Future<void> retake() => _reporting(_retake);

  Future<void> _retake() async {
    await _discardDraft();
    await _start();
  }

  /// Throws the take away and leaves the session.
  Future<void> discard() => _reporting(_discard);

  Future<void> _discard() async {
    await _discardDraft();
    state = RecordingSessionState(practiceTask: state.practiceTask);
  }

  /// Keeps the take. In a probe session, moves on to the next take.
  Future<void> save(User patient) => _reporting(() => _save(patient));

  Future<void> _save(User patient) async {
    final draft = state.draftPath;
    if (draft == null || state.stage != RecordingStage.review) return;
    state = state.copyWith(stage: RecordingStage.saving);

    await ref.read(playbackProvider.notifier).release();
    final createdAt = DateTime.now();
    final path = await ref
        .read(recordingFilesProvider)
        .keep(
          draft,
          participantCode: patient.participantCode ?? patient.id,
          type: state.type,
          task: state.task,
          createdAt: createdAt,
          trial: state.trial,
        );
    await ref
        .read(recordingRepositoryProvider)
        .save(
          Recording(
            id: const Uuid().v4(),
            patientId: patient.id,
            kind: state.kind,
            task: state.task,
            type: state.type,
            filePath: path,
            durationSec: state.elapsedSec,
            createdAt: createdAt,
            trial: state.trial,
            probeSessionId: state.probeSessionId,
          ),
        );
    ref
      ..invalidate(patientRecordingsProvider(patient.id))
      ..invalidate(probeDueProvider(patient.id));
    await ref
        .read(usageLoggerProvider)
        .record(
          UsageAction.recordingSaved,
          detail: '${state.type.name}/${state.task.name}',
          user: patient,
        );

    if (!state.isProbe) {
      state = RecordingSessionState(practiceTask: state.practiceTask);
    } else if (state.probeIndex + 1 >= ProbeProtocol.takes.length) {
      state = state.copyWith(stage: RecordingStage.probeComplete);
    } else {
      state = state.copyWith(
        stage: RecordingStage.ready,
        probeIndex: state.probeIndex + 1,
      );
    }
  }

  /// Leaves a probe session part way. Takes already kept stay saved.
  void finishLater() =>
      state = RecordingSessionState(practiceTask: state.practiceTask);

  Future<void> _discardDraft() async {
    await ref.read(playbackProvider.notifier).release();
    final path = state.draftPath;
    if (path != null) await ref.read(recordingFilesProvider).discard(path);
  }

  /// Runs [action], turning a failure into state the screen can show. A
  /// failed save returns to review so the take is not lost.
  Future<void> _reporting(Future<void> Function() action) async {
    try {
      await action();
    } on AppFailure catch (failure) {
      _ticker?.cancel();
      final stage = switch (state.stage) {
        RecordingStage.saving => RecordingStage.review,
        RecordingStage.recording => RecordingStage.review,
        final other => other,
      };
      state = state.copyWith(stage: stage, failure: failure);
    }
  }
}
