import '../../../core/utils/dates.dart';
import '../../settings/domain/study_settings.dart';
import 'recording.dart';

/// Where a patient is in the probe schedule: a baseline first, then one
/// probe every [StudySettings.probeIntervalDays] until the study ends, with
/// the final post-intervention probe due no later than the day after the
/// last intervention day.
class ProbeDue {
  const ProbeDue({required this.nextDue, required this.isBaseline});

  /// Day the next probe is due, or null once the study period is over.
  final DateTime? nextDue;

  /// True when no probe has been recorded yet.
  final bool isBaseline;

  bool isDueOn(DateTime day) {
    final due = nextDue;
    return due != null && !dateOnly(day).isBefore(due);
  }

  static ProbeDue compute({
    required DateTime enrolledOn,
    required Iterable<Recording> recordings,
    required StudySettings settings,
  }) {
    final probeDays = [
      for (final r in recordings)
        if (r.kind == RecordingKind.probe) dateOnly(r.createdAt),
    ];
    final start = dateOnly(enrolledOn);
    if (probeDays.isEmpty) return ProbeDue(nextDue: start, isBaseline: true);

    final last = probeDays.reduce((a, b) => a.isAfter(b) ? a : b);
    final next = addDays(last, settings.probeIntervalDays);
    final end = addDays(start, settings.studyWeeks * 7);
    // The post-intervention recording is a protocol requirement, so a late
    // probe pulls the final one forward to the study end rather than past
    // it.
    return ProbeDue(
      nextDue: last.isBefore(end) ? (next.isAfter(end) ? end : next) : null,
      isBaseline: false,
    );
  }
}
