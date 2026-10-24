import 'adherence.dart';
import 'completion.dart';
import 'exercise.dart';
import 'schedule.dart';

/// How many days of history adherence views look back over (8 weeks).
const historyDays = 56;

/// Window for adherence summaries, flags and status.
const recentDays = 14;

/// One assigned exercise on a patient's list for a given day.
class DayItem {
  const DayItem({
    required this.exercise,
    required this.schedule,
    required this.completions,
  });

  final Exercise exercise;

  /// The assignment version in force that day, with its dosage.
  final Schedule schedule;
  final List<Completion> completions;

  int get sessionsDone => completions.length < schedule.sessionsPerDay
      ? completions.length
      : schedule.sessionsPerDay;

  bool get isDone => sessionsDone >= schedule.sessionsPerDay;
}

/// A patient's assignments and recent history, shared by patient, therapist
/// and admin views.
class PatientActivity {
  const PatientActivity({
    required this.today,
    required this.schedules,
    required this.exercises,
    required this.completions,
    required this.days,
  });

  final DateTime today;

  /// Every assignment version, current and past.
  final List<Schedule> schedules;
  final Map<String, Exercise> exercises;
  final List<Completion> completions;

  /// Daily adherence for the last [historyDays] days, ending today.
  final List<AdherencePeriod> days;

  /// Assignments in force now, in exercise title order.
  List<Schedule> get currentSchedules =>
      [
        for (final s in schedules)
          if (s.isCurrent && exercises.containsKey(s.exerciseId)) s,
      ]..sort(
        (a, b) => exercises[a.exerciseId]!.title.compareTo(
          exercises[b.exerciseId]!.title,
        ),
      );

  AdherencePeriod get todayAdherence => days.last;

  int get streak => Adherence.streak(days);

  List<AdherencePeriod> get recent => days.sublist(days.length - recentDays);

  double? get recentRate => Adherence.rate(recent);

  /// True when recent adherence is under [threshold]. With no sessions due
  /// there is nothing to judge, so that is not flagged.
  bool isBelow(double threshold) {
    final rate = recentRate;
    return rate != null && rate < threshold;
  }

  /// When the patient last marked any session done, within the history.
  DateTime? get lastCompletedAt => completions
      .map((c) => c.completedAt)
      .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

  List<DayItem> itemsOn(DateTime day) {
    final items = [
      for (final s in schedules)
        if (s.isDueOn(day) && exercises[s.exerciseId] != null)
          DayItem(
            exercise: exercises[s.exerciseId]!,
            schedule: s,
            completions: [
              for (final c in completions)
                if (c.exerciseId == s.exerciseId && c.day == day) c,
            ]..sort((a, b) => a.completedAt.compareTo(b.completedAt)),
          ),
    ];
    return items..sort((a, b) => a.exercise.title.compareTo(b.exercise.title));
  }

  List<DayItem> get todayItems => itemsOn(today);

  /// Current assignments with their sessions due and done over the recent
  /// window, scored against whichever version was active each day.
  List<ExerciseAdherence> get exerciseBreakdown {
    final counts = Adherence.sessionCounts(completions);
    final rows = <ExerciseAdherence>[];
    for (final current in currentSchedules) {
      var due = 0;
      var done = 0;
      for (final period in recent) {
        for (final s in schedules) {
          if (s.exerciseId != current.exerciseId || !s.isDueOn(period.start)) {
            continue;
          }
          due += s.sessionsPerDay;
          final completed = counts[(period.start, s.exerciseId)] ?? 0;
          done += completed < s.sessionsPerDay ? completed : s.sessionsPerDay;
        }
      }
      rows.add(
        ExerciseAdherence(
          exercise: exercises[current.exerciseId]!,
          schedule: current,
          due: due,
          done: done,
        ),
      );
    }
    return rows;
  }
}

class ExerciseAdherence {
  const ExerciseAdherence({
    required this.exercise,
    required this.schedule,
    required this.due,
    required this.done,
  });

  final Exercise exercise;

  /// The current assignment version.
  final Schedule schedule;

  /// Sessions over the recent window.
  final int due;
  final int done;

  double? get rate => due == 0 ? null : done / due;
}

/// Dosage and targets a therapist sets when assigning or editing.
typedef Dosage = ({
  Set<int> weekdays,
  int sessionsPerDay,
  int repetitions,
  ExerciseTargets targets,
  String instructions,
});
