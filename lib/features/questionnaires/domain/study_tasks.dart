import '../../../core/utils/dates.dart';
import '../../study/domain/study_period.dart';
import 'questionnaire.dart';

enum StudyTaskKind { baselineSelfReport, weeklySelfReport, usability, feedback }

/// A questionnaire the participant should fill in now.
class StudyTask {
  const StudyTask(this.kind, {this.week = AdherenceSelfReport.baselineWeek});

  final StudyTaskKind kind;

  /// Study week for a weekly self-report.
  final int week;

  @override
  bool operator ==(Object other) =>
      other is StudyTask && other.kind == kind && other.week == week;

  @override
  int get hashCode => Object.hash(kind, week);
}

/// When each questionnaire opens:
/// - the baseline self-report until it is submitted;
/// - each week's self-report from the last day of that week for seven days,
///   so a late report still describes the right week;
/// - usability and feedback from the last intervention day on.
/// A withdrawn participant is asked for nothing.
abstract final class StudyTasks {
  static const weeklyWindowDays = 7;

  static List<StudyTask> due({
    required StudyPeriod period,
    required QuestionnaireHistory history,
    required DateTime today,
    bool withdrawn = false,
  }) {
    if (withdrawn) return const [];
    final day = dateOnly(today);
    return [
      if (history.baseline == null)
        const StudyTask(StudyTaskKind.baselineSelfReport),
      for (var week = 1; week <= period.weeks; week++)
        if (history.reportForWeek(week) == null &&
            _weeklyOpen(period, week, day))
          StudyTask(StudyTaskKind.weeklySelfReport, week: week),
      if (period.followUpOpen(day) && history.usability.isEmpty)
        const StudyTask(StudyTaskKind.usability),
      if (period.followUpOpen(day) && history.satisfaction.isEmpty)
        const StudyTask(StudyTaskKind.feedback),
    ];
  }

  static bool _weeklyOpen(StudyPeriod period, int week, DateTime day) {
    final opens = period.weekEnd(week);
    final closes = addDays(opens, weeklyWindowDays - 1);
    return !day.isBefore(opens) && !day.isAfter(closes);
  }
}
