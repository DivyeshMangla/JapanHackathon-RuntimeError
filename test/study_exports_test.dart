import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/features/admin/data/study_csv_export.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/demo_data/data/demo_study.dart';
import 'package:melo/features/questionnaires/domain/questionnaire.dart';
import 'package:melo/features/questionnaires/domain/study_tasks.dart';
import 'package:melo/features/study/domain/intervention_outcome.dart';
import 'package:melo/features/study/domain/participant_record.dart';
import 'package:melo/features/study/domain/study_period.dart';
import 'package:melo/features/usage/domain/usage_event.dart';
import 'support/exercise_fixtures.dart';

void main() {
  final patient = User(
    id: 'u1',
    role: UserRole.patient,
    name: 'Grace Liu',
    email: 'grace@example.org',
    createdAt: DateTime(2026, 9, 7),
    participantCode: 'P001',
  );
  const codes = {'u1': 'P001'};

  group('study exports', () {
    test('participant form identifies by code and marks withdrawal', () {
      final record = ParticipantRecord(
        patientId: 'u1',
        interventionStart: DateTime(2026, 9, 7),
        infoSheetProvided: true,
        consentSignedOn: DateTime(2026, 9, 5),
        demographics: const Demographics(
          ageYears: 34,
          gender: Gender.female,
          education: EducationLevel.graduate,
          occupation: 'Teacher',
          voiceUse: VoiceUseLevel.professionalVocal,
          primaryLanguage: 'English',
        ),
      ).withdraw(on: DateTime(2026, 9, 20), reason: 'Moved away');
      final csv = StudyCsvExport.participants(
        records: [record],
        patients: [patient],
      );
      expect(csv, contains('P001,2026-09-07,true,2026-09-05'));
      expect(csv, contains('withdrawn,2026-09-20,Moved away'));
      expect(csv, isNot(contains('Grace')));
      expect(csv, isNot(contains('grace@example.org')));
    });

    test('patients without a record still get a row', () {
      final csv = StudyCsvExport.participants(
        records: const [],
        patients: [patient],
      );
      expect(csv.trim().split('\n'), hasLength(2));
      expect(csv, contains('P001,2026-09-07,false'));
    });

    test('usability export holds item answers and the SUS score', () {
      final csv = StudyCsvExport.usability(
        responses: [
          UsabilityResponse(
            id: 'r',
            patientId: 'u1',
            submittedAt: DateTime(2026, 10, 4),
            answers: const [4, 2, 4, 1, 4, 2, 5, 2, 4, 2],
          ),
        ],
        codes: codes,
      );
      expect(csv.split('\n').first, contains('sus_10,sus_score'));
      expect(csv, contains('4,2,4,1,4,2,5,2,4,2,80.0'));
    });

    test('feedback export keeps open comments safely quoted', () {
      final csv = StudyCsvExport.feedback(
        responses: [
          SatisfactionResponse(
            id: 'f',
            patientId: 'u1',
            submittedAt: DateTime(2026, 10, 4),
            ratings: {for (final item in SatisfactionItem.values) item: 4},
            likedMost: 'The reminders, mostly',
            suggestions: '=add videos',
          ),
        ],
        codes: codes,
      );
      expect(csv.split('\n').first, contains('reminders_helpful'));
      expect(csv, contains('"The reminders, mostly"'));
      expect(csv, contains("'=add videos"));
    });

    test('usage log export uses participant codes', () {
      final csv = StudyCsvExport.usageLog(
        events: [
          UsageEvent(
            at: DateTime(2026, 9, 8, 9),
            patientId: 'u1',
            action: UsageAction.sessionMarked,
            detail: 'ex-plain',
          ),
        ],
        codes: codes,
      );
      expect(csv, contains('P001,2026-09-08T09:00:00.000,sessionMarked'));
    });
  });

  group('demo study data', () {
    final today = DateTime(2026, 10, 17);
    final completedStart = addDays(today, -completedStartOffset);

    test('P006 has finished the intervention with follow-up due', () {
      final schedules = finishedParticipantSchedules(
        completedPatientId,
        completedStart,
      );
      final outcome = InterventionOutcome.compute(
        period: StudyPeriod(start: completedStart, weeks: 4),
        schedules: schedules,
        completions: finishedParticipantCompletions(
          completedPatientId,
          schedules,
          completedStart,
        ),
        today: today,
      );
      expect(outcome.isComplete, isTrue);
      expect(outcome.usedEveryWeek, isTrue);
      expect(outcome.adherence, inInclusiveRange(0.75, 0.95));

      final reports = demoSelfReports({completedPatientId: completedStart});
      expect(reports.map((r) => r.week), [0, 1, 2, 3, 4]);
      final due = StudyTasks.due(
        period: StudyPeriod(start: completedStart, weeks: 4),
        history: QuestionnaireHistory(selfReports: reports),
        today: today,
      );
      expect(due.map((t) => t.kind), [
        StudyTaskKind.usability,
        StudyTaskKind.feedback,
      ]);
    });

    test('every seeded patient gets a consented study record', () {
      final starts = {
        for (var n = 1; n <= 6; n++) 'patient-P00$n': DateTime(2026, 10, 2),
      };
      final records = demoParticipantRecords(starts);
      expect(records, hasLength(6));
      expect(records.every((r) => r.hasConsent), isTrue);
      expect(
        records.where((r) => r.orientationOn == null).map((r) => r.patientId),
        ['patient-P005'],
      );
    });
  });
}
