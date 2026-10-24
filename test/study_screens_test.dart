import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/theme/app_theme.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/core/utils/l10n.dart';
import 'package:melo/features/admin/presentation/controllers/admin_controllers.dart';
import 'package:melo/features/admin/presentation/study_outcomes_screen.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/auth/presentation/controllers/auth_controller.dart';
import 'package:melo/features/demo_data/data/demo_study.dart';
import 'package:melo/features/education/domain/education_topic.dart';
import 'package:melo/features/education/presentation/learn_screen.dart';
import 'package:melo/features/education/presentation/learn_topic_screen.dart';
import 'package:melo/features/exercises/domain/adherence.dart';
import 'package:melo/features/exercises/domain/patient_activity.dart';
import 'package:melo/features/questionnaires/domain/questionnaire.dart';
import 'package:melo/features/questionnaires/presentation/feedback_screen.dart';
import 'package:melo/features/questionnaires/presentation/self_report_screen.dart';
import 'package:melo/features/questionnaires/presentation/usability_screen.dart';
import 'package:melo/features/recordings/domain/probe_schedule.dart';
import 'package:melo/features/study/domain/intervention_outcome.dart';
import 'package:melo/features/study/domain/participant_status.dart';
import 'package:melo/features/study/domain/study_outcomes.dart';
import 'package:melo/features/study/domain/study_period.dart';
import 'package:melo/features/therapist/domain/participant_study.dart';
import 'package:melo/features/therapist/domain/participant_summary.dart';
import 'package:melo/features/therapist/presentation/assessment_screen.dart';
import 'package:melo/features/therapist/presentation/controllers/caseload_controllers.dart';
import 'package:melo/features/therapist/presentation/monitoring_form_screen.dart';
import 'package:melo/features/therapist/presentation/study_record_screen.dart';
import 'package:melo/features/usage/domain/usage_event.dart';
import 'package:melo/features/usage/presentation/controllers/usage_controllers.dart';
import 'support/exercise_fixtures.dart';

/// Records usage in memory instead of storage.
class _RecordingUsageLogger implements UsageLogger {
  final actions = <UsageAction>[];

  @override
  Future<void> record(
    UsageAction action, {
    String detail = '',
    User? user,
  }) async => actions.add(action);
}

final _today = dateOnly(DateTime.now());
final _start = addDays(_today, -completedStartOffset);

final _patient = User(
  id: completedPatientId,
  role: UserRole.patient,
  name: completedPatientName,
  email: 'p006@melo.local',
  createdAt: _start,
  participantCode: completedPatientCode,
  therapistId: completedPatientTherapist,
);

/// P006 from the demo data: a full four weeks with follow-up pending.
ParticipantStudy _study() {
  final schedules = finishedParticipantSchedules(completedPatientId, _start);
  final completions = finishedParticipantCompletions(
    completedPatientId,
    schedules,
    _start,
  );
  final from = addDays(_today, 1 - historyDays);
  final starts = {completedPatientId: _start};
  return ParticipantStudy(
    summary: ParticipantSummary(
      patient: _patient,
      activity: PatientActivity(
        today: _today,
        schedules: schedules,
        exercises: fixtureLibrary,
        completions: completions,
        days: Adherence.daily(
          schedules: schedules,
          completions: completions,
          from: from,
          to: _today,
        ),
      ),
      recordings: const [],
      lowAdherence: false,
      status: ParticipantStatus.awaitingProbe,
      probeDue: ProbeDue(nextDue: _today, isBaseline: false),
    ),
    record: demoParticipantRecords(starts).single,
    outcome: InterventionOutcome.compute(
      period: StudyPeriod(start: _start, weeks: 4),
      schedules: schedules,
      completions: completions,
      today: _today,
    ),
    questionnaires: QuestionnaireHistory(selfReports: demoSelfReports(starts)),
    monitoring: demoMonitoring(starts),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List<Object> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_patient),
        usageLoggerProvider.overrideWithValue(_RecordingUsageLogger()),
        ...overrides.cast(),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('patient screens render on a phone', () {
    testWidgets('learn index and every topic', (tester) async {
      await _pump(tester, const LearnScreen());
      expect(find.text('Using the app'), findsOneWidget);
      for (final topic in EducationTopic.values) {
        await _pump(tester, LearnTopicScreen(topicName: topic.name));
        expect(tester.takeException(), isNull);
      }
      await _pump(tester, const LearnTopicScreen(topicName: 'nope'));
      expect(find.text('Topic not found'), findsOneWidget);
    });

    testWidgets('self-report shows inline errors before submitting', (
      tester,
    ) async {
      await _pump(tester, const SelfReportScreen(week: 0));
      await tester.scrollUntilVisible(
        find.text('Submit answers'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Submit answers'));
      await tester.pump();
      // The pill layout is taller; return to the questions after submitting.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(250);
      await tester.pumpAndSettle();
      expect(find.text('Answer this question.'), findsNWidgets(2));
    });

    testWidgets('usability and feedback questionnaires', (tester) async {
      await _pump(tester, const UsabilityScreen());
      expect(find.textContaining('use this app frequently'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Submit answers'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Submit answers'));
      await tester.pump();
      expect(
        find.text('10 questions still need an answer.', skipOffstage: false),
        findsOneWidget,
      );
      await _pump(tester, const FeedbackScreen());
      expect(find.textContaining('reminders helped'), findsOneWidget);
    });
  });

  group('staff screens render on a phone', () {
    final study = _study();
    final overrides = [
      participantStudyProvider.overrideWith((ref, id) async => study),
    ];

    testWidgets('assessment with weekly sources', (tester) async {
      await _pump(
        tester,
        const AssessmentScreen(patientId: completedPatientId),
        overrides: overrides,
      );
      expect(find.text('Baseline assessment'), findsOneWidget);
      // Scrolls past every week card to the follow-up section.
      await tester.scrollUntilVisible(
        find.text('Follow-up assessment'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Satisfaction feedback'), findsOneWidget);
    });

    testWidgets('study record form', (tester) async {
      await _pump(
        tester,
        const StudyRecordScreen(patientId: completedPatientId),
        overrides: overrides,
      );
      expect(find.text('Demographic information'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sales representative'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sales representative'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Record withdrawal'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.text('Muscle tension dysphonia'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Muscle tension dysphonia'), findsOneWidget);
    });

    testWidgets('monitoring form', (tester) async {
      await _pump(
        tester,
        const MonitoringFormScreen(patientId: completedPatientId, week: 2),
        overrides: overrides,
      );
      expect(find.text('For reference this week'), findsOneWidget);
    });

    testWidgets('study outcomes', (tester) async {
      final participant = ParticipantOutcome(
        patientId: completedPatientId,
        code: completedPatientCode,
        record: study.record,
        outcome: study.outcome,
        questionnaires: study.questionnaires,
      );
      await _pump(
        tester,
        const StudyOutcomesScreen(),
        overrides: [
          studyOutcomesProvider.overrideWith(
            (ref) async => StudyOutcomes.compute(
              participants: [participant],
              approached: 3,
              adherenceThreshold: 0.8,
              today: _today,
            ),
          ),
        ],
      );
      expect(find.text('Recruitment rate'), findsOneWidget);
      expect(find.text('33% (1 of 3)'), findsOneWidget);
    });
  });
}
