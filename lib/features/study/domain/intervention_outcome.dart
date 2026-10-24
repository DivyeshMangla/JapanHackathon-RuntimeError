import '../../../core/utils/dates.dart';
import '../../exercises/domain/adherence.dart';
import '../../exercises/domain/completion.dart';
import '../../exercises/domain/schedule.dart';
import 'study_period.dart';

/// Adherence and compliance for one study week.
class WeekOutcome {
  const WeekOutcome({
    required this.week,
    required this.start,
    required this.sessionsDue,
    required this.sessionsDone,
    required this.prescribedDays,
    required this.fullDoseDays,
    required this.practiceDays,
  });

  /// 1-based study week.
  final int week;
  final DateTime start;
  final int sessionsDue;
  final int sessionsDone;

  /// Days with at least one session prescribed.
  final int prescribedDays;

  /// Prescribed days on which every prescribed session was completed.
  final int fullDoseDays;

  /// Prescribed days with at least one session completed.
  final int practiceDays;

  double? get adherence => sessionsDue == 0 ? null : sessionsDone / sessionsDue;

  double? get compliance =>
      prescribedDays == 0 ? null : fullDoseDays / prescribedDays;
}

/// Primary outcomes over the intervention, from the application log.
///
/// Adherence follows the protocol formula: completed sessions over
/// prescribed sessions. Compliance measures whether the participant kept to
/// the recommended frequency and schedule: the share of prescribed days on
/// which the full daily dose (every session of every assigned exercise) was
/// completed on that day. Only finished days are scored.
class InterventionOutcome {
  const InterventionOutcome({
    required this.period,
    required this.weeks,
    required this.scoredThrough,
  });

  factory InterventionOutcome.compute({
    required StudyPeriod period,
    required List<Schedule> schedules,
    required List<Completion> completions,
    required DateTime today,
  }) {
    final through = period.lastScoredDay(today);
    if (through == null) {
      return InterventionOutcome(
        period: period,
        weeks: const [],
        scoredThrough: null,
      );
    }
    final days = Adherence.daily(
      schedules: schedules,
      completions: completions,
      from: period.start,
      to: through,
    );
    final weeks = <WeekOutcome>[];
    for (var week = 1; week <= period.weeks; week++) {
      final start = period.weekStart(week);
      if (start.isAfter(through)) break;
      final end = period.weekEnd(week);
      final inWeek = [
        for (final d in days)
          if (!d.start.isBefore(start) && !d.start.isAfter(end)) d,
      ];
      final prescribed = inWeek.where((d) => d.due > 0);
      weeks.add(
        WeekOutcome(
          week: week,
          start: start,
          sessionsDue: inWeek.fold(0, (sum, d) => sum + d.due),
          sessionsDone: inWeek.fold(0, (sum, d) => sum + d.done),
          prescribedDays: prescribed.length,
          fullDoseDays: prescribed.where((d) => d.isComplete).length,
          practiceDays: prescribed.where((d) => d.done > 0).length,
        ),
      );
    }
    return InterventionOutcome(
      period: period,
      weeks: weeks,
      scoredThrough: through,
    );
  }

  final StudyPeriod period;
  final List<WeekOutcome> weeks;

  /// Last day included in the scores, or null before the first full day.
  final DateTime? scoredThrough;

  int get sessionsDue => weeks.fold(0, (sum, w) => sum + w.sessionsDue);
  int get sessionsDone => weeks.fold(0, (sum, w) => sum + w.sessionsDone);
  int get prescribedDays => weeks.fold(0, (sum, w) => sum + w.prescribedDays);
  int get fullDoseDays => weeks.fold(0, (sum, w) => sum + w.fullDoseDays);
  int get practiceDays => weeks.fold(0, (sum, w) => sum + w.practiceDays);

  /// Completed sessions over prescribed sessions, or null when nothing was
  /// prescribed yet.
  double? get adherence => sessionsDue == 0 ? null : sessionsDone / sessionsDue;

  /// Full-dose days over prescribed days.
  double? get compliance =>
      prescribedDays == 0 ? null : fullDoseDays / prescribedDays;

  /// Prescribed days with any practice over prescribed days.
  double? get practiceDayRate =>
      prescribedDays == 0 ? null : practiceDays / prescribedDays;

  bool get isComplete =>
      scoredThrough != null && !dateOnly(scoredThrough!).isBefore(period.end);

  /// The participant marked practice in every study week that prescribed
  /// any, through the end of the intervention. Feeds the feasibility
  /// measure "app usage completion".
  bool get usedEveryWeek =>
      isComplete &&
      weeks.length == period.weeks &&
      weeks.every((w) => w.sessionsDue == 0 || w.sessionsDone > 0);
}
