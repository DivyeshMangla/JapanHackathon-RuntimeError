import 'exercise_demo.dart';

/// Speaks short coaching cues aloud during a guided exercise. Spoken
/// guidance is a nicety on top of the on-screen cues, so implementations
/// never throw: a failure is logged and the exercise carries on silently.
abstract interface class CueSpeaker {
  /// Speaks [cue], cutting off any cue still playing so the voice never
  /// lags behind the animation.
  Future<void> speak(DemoCue cue);

  Future<void> stop();
}
