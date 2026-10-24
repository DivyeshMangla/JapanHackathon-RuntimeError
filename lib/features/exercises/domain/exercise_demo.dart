/// What the patient should be doing during one phase of a guided
/// demonstration. Display text lives in l10n.
enum DemoCue { breatheIn, breatheOut }

class DemoPhase {
  const DemoPhase(this.cue, this.duration);

  final DemoCue cue;
  final Duration duration;
}

/// Where a demonstration is at a moment in time.
class DemoPosition {
  const DemoPosition({
    required this.repetition,
    required this.phase,
    required this.progress,
    required this.remaining,
    required this.finished,
  });

  /// 1-based repetition number.
  final int repetition;
  final DemoPhase phase;

  /// 0 to 1 through the current phase.
  final double progress;

  /// Time left in the current phase.
  final Duration remaining;
  final bool finished;
}

/// One repetition of a guided exercise as timed phases. Every animated
/// exercise is driven by a script, so they all share one player and pace
/// the same way.
class DemoScript {
  /// [phases] must not be empty.
  const DemoScript(this.phases);

  final List<DemoPhase> phases;

  Duration get cycle =>
      phases.fold(Duration.zero, (sum, phase) => sum + phase.duration);

  Duration total(int repetitions) => cycle * repetitions;

  DemoPosition positionAt(Duration elapsed, int repetitions) {
    final reps = repetitions < 1 ? 1 : repetitions;
    if (elapsed >= total(reps)) {
      return DemoPosition(
        repetition: reps,
        phase: phases.last,
        progress: 1,
        remaining: Duration.zero,
        finished: true,
      );
    }
    final clamped = elapsed.isNegative ? Duration.zero : elapsed;
    final cycleMicros = cycle.inMicroseconds;
    final rep = clamped.inMicroseconds ~/ cycleMicros;
    var within = clamped.inMicroseconds - rep * cycleMicros;
    for (final phase in phases) {
      final length = phase.duration.inMicroseconds;
      if (within < length) {
        return DemoPosition(
          repetition: rep + 1,
          phase: phase,
          progress: within / length,
          remaining: Duration(microseconds: length - within),
          finished: false,
        );
      }
      within -= length;
    }
    // Unreachable: within is always less than the cycle length.
    throw StateError('Elapsed time fell outside the demonstration cycle.');
  }
}

/// The source document gives no breath timing. A longer exhale than inhale
/// is the usual teaching pattern for calm low breathing; the clinical team
/// should confirm these values.
const diaphragmaticBreathingScript = DemoScript([
  DemoPhase(DemoCue.breatheIn, Duration(seconds: 4)),
  DemoPhase(DemoCue.breatheOut, Duration(seconds: 6)),
]);
