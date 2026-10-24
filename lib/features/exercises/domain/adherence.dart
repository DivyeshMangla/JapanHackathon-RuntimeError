import '../../../core/utils/dates.dart';
import 'completion.dart';
import 'schedule.dart';

/// Sessions prescribed and completed over one period (a day or a week).
class AdherencePeriod {
  const AdherencePeriod({
    required this.start,
    required this.due,
    required this.done,
  });

  final DateTime start;

  /// Sessions prescribed.
  final int due;

  /// Sessions completed, never more than [due].
  final int done;

  /// Null when nothing was due, so rest days do not count as misses.
  double? get rate => due == 0 ? null : done / due;

  bool get isComplete => due > 0 && done >= due;
}

/// Adherence is sessions completed over sessions prescribed (research doc
/// 8.2), scored day by day against the assignment version active that day.
abstract final class Adherence {
  /// Completed sessions per exercise per day.
  static Map<(DateTime, String), int> sessionCounts(
    Iterable<Completion> completions,
  ) {
    final counts = <(DateTime, String), int>{};
    for (final c in completions) {
      final key = (dateOnly(c.day), c.exerciseId);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// One entry per day from [from] to [to] inclusive. Completions only count
  /// toward a schedule version that was active and due that day, and never
  /// beyond its sessions per day.
  static List<AdherencePeriod> daily({
    required List<Schedule> schedules,
    required List<Completion> completions,
    required DateTime from,
    required DateTime to,
  }) {
    final counts = sessionCounts(completions);
    final days = <AdherencePeriod>[];
    for (var day = dateOnly(from); !day.isAfter(to); day = addDays(day, 1)) {
      var due = 0;
      var done = 0;
      for (final s in schedules) {
        if (!s.isDueOn(day)) continue;
        due += s.sessionsPerDay;
        final completed = counts[(day, s.exerciseId)] ?? 0;
        done += completed < s.sessionsPerDay ? completed : s.sessionsPerDay;
      }
      days.add(AdherencePeriod(start: day, due: due, done: done));
    }
    return days;
  }

  /// Groups daily entries into Monday-start weeks.
  static List<AdherencePeriod> weekly(List<AdherencePeriod> days) {
    final weeks = <DateTime, (int, int)>{};
    for (final d in days) {
      final key = startOfWeek(d.start);
      final (due, done) = weeks[key] ?? (0, 0);
      weeks[key] = (due + d.due, done + d.done);
    }
    return [
      for (final MapEntry(:key, :value) in weeks.entries)
        AdherencePeriod(start: key, due: value.$1, done: value.$2),
    ];
  }

  /// Overall completion rate, or null when nothing was due.
  static double? rate(Iterable<AdherencePeriod> periods) {
    var due = 0;
    var done = 0;
    for (final p in periods) {
      due += p.due;
      done += p.done;
    }
    return due == 0 ? null : done / due;
  }

  /// Consecutive fully completed days ending at the last entry. Rest days are
  /// skipped, and an unfinished final day (today) does not break the streak.
  static int streak(List<AdherencePeriod> days) {
    var count = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      final day = days[i];
      if (day.due == 0) continue;
      if (day.isComplete) {
        count++;
      } else if (i != days.length - 1) {
        break;
      }
    }
    return count;
  }
}
