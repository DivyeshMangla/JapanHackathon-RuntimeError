import 'recording.dart';

/// One probe task and how many trials of it to record.
typedef ProbeStep = ({RecordingTask task, int trials});

/// The fixed probe protocol: identical tasks for every patient at every probe
/// (research doc 8.1, section 14). Softest and loudest /a/ are left out
/// because they need a calibrated microphone.
abstract final class ProbeProtocol {
  static const steps = <ProbeStep>[
    (task: RecordingTask.sustainedA, trials: 3),
    (task: RecordingTask.maximumA, trials: 3),
    (task: RecordingTask.sustainedS, trials: 2),
    (task: RecordingTask.sustainedZ, trials: 2),
    (task: RecordingTask.vowelA, trials: 1),
    (task: RecordingTask.vowelI, trials: 1),
    (task: RecordingTask.vowelU, trials: 1),
    (task: RecordingTask.pitchGlide, trials: 2),
    (task: RecordingTask.readingPassage, trials: 1),
    (task: RecordingTask.spontaneousSpeech, trials: 1),
  ];

  /// Every take in order, e.g. sustained /a/ trial 1, 2, 3, then maximum /a/.
  static final takes = [
    for (final step in steps)
      for (var trial = 1; trial <= step.trials; trial++)
        (task: step.task, trial: trial, of: step.trials),
  ];

  /// Silence before each task, per the recording protocol.
  static const leadIn = Duration(milliseconds: 500);
}
