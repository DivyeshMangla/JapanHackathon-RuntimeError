import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/features/exercises/domain/completion.dart';
import 'package:melo/features/exercises/domain/schedule.dart';
import 'package:melo/features/questionnaires/domain/questionnaire.dart';
import 'package:melo/features/questionnaires/domain/study_tasks.dart';
import 'package:melo/features/recordings/domain/probe_schedule.dart';
import 'package:melo/features/recordings/domain/recording.dart';
import 'package:melo/features/settings/domain/study_settings.dart';
import 'package:melo/features/study/domain/intervention_outcome.dart';
import 'package:melo/features/study/domain/participant_record.dart';
import 'package:melo/features/study/domain/statistics.dart';
import 'package:melo/features/study/domain/study_outcomes.dart';
import 'package:melo/features/study/domain/study_period.dart';

final _start = DateTime(2026, 9, 7);

Schedule _daily({int sessions = 2}) => Schedule(
  id: 's1',
  patientId: 'p',
  exerciseId: 'ex',
  weekdays: const {1, 2, 3, 4, 5, 6, 7},
  effectiveFrom: _start,
  sessionsPerDay: sessions,
);

List<Completion> _sessions(DateTime day, int count) => [
  for (var i = 0; i < count; i++)
    Completion(
      id: 'c-$day-$i',
      patientId: 'p',
      exerciseId: 'ex',
      day: day,
      completedAt: day.add(Duration(hours: 9 + i)),
    ),
];

AdherenceSelfReport _report(int week, int days) => AdherenceSelfReport(
  id: 'r$week',
  patientId: 'p',
  week: week,
  submittedAt: _start,
  daysPractised: days,
  barrier: PracticeBarrier.none,
);

void main() {
  group('study period', () {
    final period = StudyPeriod(start: _start, weeks: 4);

    test('spans four weeks with the follow-up the day after', () {
      expect(period.end, DateTime(2026, 10, 4));
      expect(period.followUpDay, DateTime(2026, 10, 5));
      expect(period.weekOf(_start), 1);
      expect(period.weekOf(DateTime(2026, 9, 14)), 2);
      expect(period.weekOf(DateTime(2026, 10, 4)), 4);
      expect(period.weekOf(DateTime(2026, 10, 5)), isNull);
    });

    test('scores finished days only', () {
      expect(period.lastScoredDay(_start), isNull);
      expect(period.lastScoredDay(DateTime(2026, 9, 10)), DateTime(2026, 9, 9));
      expect(period.lastScoredDay(DateTime(2026, 11, 1)), period.end);
    });
  });

  group('intervention adherence and compliance', () {
    final period = StudyPeriod(start: _start, weeks: 1);

    test('adherence is completed over prescribed sessions', () {
      final completions = [
        for (var d = 0; d < 7; d++)
          ..._sessions(addDays(_start, d), d < 4 ? 2 : 1),
      ];
      final outcome = InterventionOutcome.compute(
        period: period,
        schedules: [_daily()],
        completions: completions,
        today: addDays(_start, 10),
      );
      expect(outcome.sessionsDue, 14);
      expect(outcome.sessionsDone, 11);
      expect(outcome.adherence, closeTo(11 / 14, 1e-9));
      // Four days met the full twice-daily dose; three had one session.
      expect(outcome.compliance, closeTo(4 / 7, 1e-9));
      expect(outcome.practiceDayRate, 1);
      expect(outcome.isComplete, isTrue);
      expect(outcome.usedEveryWeek, isTrue);
    });

    test('extra sessions never lift adherence above the dose', () {
      final outcome = InterventionOutcome.compute(
        period: period,
        schedules: [_daily()],
        completions: _sessions(_start, 5),
        today: addDays(_start, 1),
      );
      expect(outcome.sessionsDone, 2);
      expect(outcome.adherence, 1);
      expect(outcome.isComplete, isFalse);
    });

    test('a week without practice fails usage completion', () {
      final outcome = InterventionOutcome.compute(
        period: StudyPeriod(start: _start, weeks: 2),
        schedules: [_daily()],
        completions: _sessions(_start, 2),
        today: addDays(_start, 20),
      );
      expect(outcome.weeks, hasLength(2));
      expect(outcome.weeks.last.sessionsDone, 0);
      expect(outcome.usedEveryWeek, isFalse);
    });
  });

  group('study tasks', () {
    final period = StudyPeriod(start: _start, weeks: 4);

    List<StudyTask> due(DateTime today, QuestionnaireHistory history) =>
        StudyTasks.due(period: period, history: history, today: today);

    test('the baseline self-report is asked for first', () {
      expect(due(_start, const QuestionnaireHistory()), [
        const StudyTask(StudyTaskKind.baselineSelfReport),
      ]);
    });

    test('weekly reports open on the last day of the week for 7 days', () {
      final history = QuestionnaireHistory(selfReports: [_report(0, 3)]);
      expect(due(addDays(_start, 5), history), isEmpty);
      expect(due(addDays(_start, 6), history), [
        const StudyTask(StudyTaskKind.weeklySelfReport, week: 1),
      ]);
      expect(due(addDays(_start, 12), history), [
        const StudyTask(StudyTaskKind.weeklySelfReport, week: 1),
      ]);
      expect(due(addDays(_start, 13), history), [
        const StudyTask(StudyTaskKind.weeklySelfReport, week: 2),
      ]);
    });

    test('follow-up questionnaires open on the last intervention day', () {
      final history = QuestionnaireHistory(
        selfReports: [for (var w = 0; w <= 4; w++) _report(w, 5)],
      );
      expect(due(addDays(period.end, -1), history), isEmpty);
      expect(due(period.end, history), [
        const StudyTask(StudyTaskKind.usability),
        const StudyTask(StudyTaskKind.feedback),
      ]);
    });

    test('withdrawn participants are asked for nothing', () {
      expect(
        StudyTasks.due(
          period: period,
          history: const QuestionnaireHistory(),
          today: _start,
          withdrawn: true,
        ),
        isEmpty,
      );
    });
  });

  group('questionnaire scoring', () {
    test('SUS scores 0 to 100 with alternating item polarity', () {
      UsabilityResponse sus(List<int> answers) => UsabilityResponse(
        id: 'u',
        patientId: 'p',
        submittedAt: _start,
        answers: answers,
      );
      expect(sus([5, 1, 5, 1, 5, 1, 5, 1, 5, 1]).score, 100);
      expect(sus([1, 5, 1, 5, 1, 5, 1, 5, 1, 5]).score, 0);
      expect(sus([3, 3, 3, 3, 3, 3, 3, 3, 3, 3]).score, 50);
      expect(sus([4, 2, 4, 1, 4, 2, 5, 2, 4, 2]).score, 80);
      expect(() => sus([3, 3]), throwsArgumentError);
    });

    test('feedback needs every item rated', () {
      expect(
        () => SatisfactionResponse(
          id: 'f',
          patientId: 'p',
          submittedAt: _start,
          ratings: const {SatisfactionItem.overallSatisfied: 4},
        ),
        throwsArgumentError,
      );
    });
  });

  group('statistics', () {
    test('descriptive values use the sample standard deviation', () {
      final d = Descriptive.of([2, 4, 4, 4, 5, 5, 7, 9])!;
      expect(d.n, 8);
      expect(d.mean, 5);
      expect(d.median, 4.5);
      expect(d.sd, closeTo(2.13809, 1e-5));
      expect(Descriptive.of([3])!.sd, isNull);
      expect(Descriptive.of([]), isNull);
    });

    // Reference values from scipy.stats 1.x.
    test('paired t-test matches scipy ttest_rel', () {
      final result = PairedTests.tTest([1, 2, 3, 4, 5], [2, 4, 5, 4, 9])!;
      expect(result.df, 4);
      expect(result.meanDifference, closeTo(1.8, 1e-9));
      expect(result.t, closeTo(2.713602, 1e-6));
      expect(result.p, closeTo(0.053338, 1e-5));
    });

    test('Wilcoxon exact p matches scipy without ties', () {
      final result = PairedTests.wilcoxon(
        [1, 2, 3, 4, 5, 6, 7.5],
        [3, 5.5, 8, 1, 9.25, 4.1, 6],
      )!;
      expect(result.exact, isTrue);
      expect(result.wMinus, 7);
      expect(result.p, closeTo(0.296875, 1e-9));
    });

    test('Wilcoxon falls back to the corrected normal approximation', () {
      final result = PairedTests.wilcoxon(
        [1, 2, 3, 4, 5, 1, 1],
        [2, 4, 5, 4, 9, 7, 3],
      )!;
      expect(result.exact, isFalse);
      expect(result.n, 6);
      expect(result.wMinus, 0);
      expect(result.p, closeTo(0.034006, 1e-4));
    });

    test('tests are undefined without variation', () {
      expect(PairedTests.tTest([1], [2]), isNull);
      expect(PairedTests.tTest([1, 2], [2, 3]), isNull);
      expect(PairedTests.wilcoxon([1, 2], [1, 2]), isNull);
    });
  });

  group('feasibility', () {
    ParticipantOutcome participant(
      String code, {
      required DateTime start,
      required bool practisedEveryWeek,
      bool withdrawn = false,
    }) {
      final period = StudyPeriod(start: start, weeks: 1);
      var record = ParticipantRecord(patientId: code, interventionStart: start);
      if (withdrawn) record = record.withdraw(on: start, reason: 'moved');
      return ParticipantOutcome(
        patientId: code,
        code: code,
        record: record,
        outcome: InterventionOutcome.compute(
          period: period,
          schedules: [_daily().copyWith(effectiveFrom: start)],
          completions: [
            if (practisedEveryWeek)
              for (final c in _sessions(start, 2))
                Completion(
                  id: c.id,
                  patientId: code,
                  exerciseId: c.exerciseId,
                  day: c.day,
                  completedAt: c.completedAt,
                ),
          ],
          today: addDays(_start, 30),
        ),
        questionnaires: const QuestionnaireHistory(),
      );
    }

    test('recruitment, retention and usage completion', () {
      final outcomes = StudyOutcomes.compute(
        participants: [
          participant('P1', start: _start, practisedEveryWeek: true),
          participant('P2', start: _start, practisedEveryWeek: false),
          participant(
            'P3',
            start: _start,
            practisedEveryWeek: true,
            withdrawn: true,
          ),
          participant(
            'P4',
            start: addDays(_start, 28),
            practisedEveryWeek: true,
          ),
        ],
        approached: 10,
        adherenceThreshold: 0.8,
        today: addDays(_start, 30),
      );
      expect(outcomes.recruitment!.rate, 0.4);
      expect(outcomes.retention.count, 3);
      expect(outcomes.retention.rate, 0.75);
      // P4 is still in the intervention, so only P1-P3 have reached the end.
      expect(outcomes.usageCompletion.total, 3);
      expect(outcomes.usageCompletion.count, 1);
      expect(outcomes.completedIntervention, 2);
    });

    test('recruitment rate is unknown until approached is entered', () {
      final outcomes = StudyOutcomes.compute(
        participants: const [],
        approached: null,
        adherenceThreshold: 0.8,
        today: _start,
      );
      expect(outcomes.recruitment, isNull);
      expect(outcomes.retention.rate, isNull);
    });
  });

  group('post-intervention probe', () {
    Recording probe(DateTime at) => Recording(
      id: 'r-$at',
      patientId: 'p',
      kind: RecordingKind.probe,
      task: RecordingTask.sustainedA,
      type: RecordingType.followUp,
      filePath: 'x.wav.vpa',
      durationSec: 3,
      createdAt: at,
    );

    test('a late probe pulls the final one forward to the study end', () {
      final due = ProbeDue.compute(
        enrolledOn: _start,
        recordings: [probe(DateTime(2026, 9, 30))],
        settings: const StudySettings(),
      );
      expect(due.nextDue, DateTime(2026, 10, 5));
    });
  });
}
