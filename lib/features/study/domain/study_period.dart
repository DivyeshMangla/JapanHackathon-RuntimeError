import '../../../core/utils/dates.dart';

/// A participant's intervention window: [weeks] weeks of app use from
/// [start]. Follow-up assessment happens once it has ended.
class StudyPeriod {
  StudyPeriod({required DateTime start, required this.weeks})
    : start = dateOnly(start);

  final DateTime start;
  final int weeks;

  int get totalDays => weeks * 7;

  /// Last day of the intervention, inclusive.
  DateTime get end => addDays(start, totalDays - 1);

  /// The day after the last intervention day, when the post-intervention
  /// recording is due.
  DateTime get followUpDay => addDays(start, totalDays);

  bool contains(DateTime day) {
    final date = dateOnly(day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  /// 1-based study week of [day], or null outside the intervention.
  int? weekOf(DateTime day) {
    if (!contains(day)) return null;
    return dateOnly(day).difference(start).inDays ~/ 7 + 1;
  }

  DateTime weekStart(int week) => addDays(start, (week - 1) * 7);

  DateTime weekEnd(int week) => addDays(start, week * 7 - 1);

  bool hasStarted(DateTime today) => !dateOnly(today).isBefore(start);

  bool hasEnded(DateTime today) => dateOnly(today).isAfter(end);

  /// True from the last day of the intervention on, when the follow-up
  /// questionnaires open.
  bool followUpOpen(DateTime today) => !dateOnly(today).isBefore(end);

  /// Last fully elapsed day of the intervention as of [today], or null when
  /// no day has finished yet. Today is excluded because the patient still
  /// has time to practise.
  DateTime? lastScoredDay(DateTime today) {
    final yesterday = addDays(dateOnly(today), -1);
    if (yesterday.isBefore(start)) return null;
    return yesterday.isAfter(end) ? end : yesterday;
  }
}
