import 'package:flutter_test/flutter_test.dart';
import 'package:melo/features/admin/data/csv_export.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/exercises/domain/completion.dart';
import 'package:melo/features/exercises/domain/exercise.dart';
import 'package:melo/features/recordings/domain/probe_schedule.dart';
import 'package:melo/features/recordings/domain/recording.dart';
import 'package:melo/features/settings/domain/study_settings.dart';
import 'package:melo/features/study/domain/participant_status.dart';

Recording _probe(DateTime at) => Recording(
  id: 'r-$at',
  patientId: 'p',
  kind: RecordingKind.probe,
  task: RecordingTask.sustainedA,
  type: RecordingType.baseline,
  filePath: 'x.wav.vpa',
  durationSec: 3,
  createdAt: at,
);

void main() {
  group('status matrix (research doc 8.3)', () {
    ParticipantStatus status(bool high, ProbeOutcome? probe) =>
        ParticipantStatus.from(highAdherence: high, probe: probe);

    test('maps every row of the matrix', () {
      expect(status(true, ProbeOutcome.positive), ParticipantStatus.onTrack);
      expect(status(true, ProbeOutcome.stable), ParticipantStatus.plateau);
      expect(status(true, ProbeOutcome.mixed), ParticipantStatus.plateau);
      expect(
        status(false, ProbeOutcome.stable),
        ParticipantStatus.adherenceProblem,
      );
      expect(
        status(true, ProbeOutcome.negative),
        ParticipantStatus.needsReview,
      );
      expect(
        status(false, ProbeOutcome.negative),
        ParticipantStatus.needsReview,
      );
      expect(
        status(false, ProbeOutcome.positive),
        ParticipantStatus.improvingDespiteLowPractice,
      );
    });

    test('without a probe rating the status is undecided', () {
      expect(status(true, null), ParticipantStatus.awaitingProbe);
      expect(status(false, null), ParticipantStatus.awaitingProbe);
    });
  });

  group('probe schedule', () {
    final enrolled = DateTime(2026, 9, 1);
    const settings = StudySettings();

    test('a baseline is due first', () {
      final due = ProbeDue.compute(
        enrolledOn: enrolled,
        recordings: const [],
        settings: settings,
      );
      expect(due.isBaseline, isTrue);
      expect(due.nextDue, enrolled);
    });

    test('later probes follow the interval and stop at the study end', () {
      final weekly = ProbeDue.compute(
        enrolledOn: enrolled,
        recordings: [_probe(DateTime(2026, 9, 1, 10))],
        settings: settings,
      );
      expect(weekly.nextDue, DateTime(2026, 9, 8));
      expect(weekly.isDueOn(DateTime(2026, 9, 7)), isFalse);
      expect(weekly.isDueOn(DateTime(2026, 9, 8)), isTrue);

      final finished = ProbeDue.compute(
        enrolledOn: enrolled,
        recordings: [_probe(DateTime(2026, 9, 29))],
        settings: settings,
      );
      expect(finished.nextDue, isNull);
    });
  });

  group('CSV export', () {
    final patient = User(
      id: 'u1',
      role: UserRole.patient,
      name: 'Grace Liu',
      email: 'grace@example.org',
      createdAt: DateTime(2026),
      participantCode: 'P001',
    );
    final codes = CsvExport.participantCodes([patient]);

    test('identifies patients by participant code only', () {
      final csv = CsvExport.completions(
        completions: [
          Completion(
            id: 'c1',
            patientId: 'u1',
            exerciseId: 'ex',
            day: DateTime(2026, 10, 5),
            completedAt: DateTime(2026, 10, 5, 9),
          ),
        ],
        codes: codes,
        exercises: const {},
      );
      expect(csv, contains('P001'));
      expect(csv, isNot(contains('Grace')));
      expect(csv, isNot(contains('grace@example.org')));
      expect(csv, isNot(contains('u1,')));
    });

    test('quotes delimiters and defuses spreadsheet formulas', () {
      final csv = CsvExport.completions(
        completions: [
          Completion(
            id: 'c1',
            patientId: 'u1',
            exerciseId: 'ex',
            day: DateTime(2026, 10, 5),
            completedAt: DateTime(2026, 10, 5, 9),
          ),
        ],
        codes: codes,
        exercises: const {
          'ex': Exercise(
            id: 'ex',
            title: '=HYPERLINK("x"), hum',
            program: 'SOVT',
            summary: '',
            steps: [],
            durationMinutes: 1,
            repetitions: 1,
          ),
        },
      );
      expect(csv, contains('"\'=HYPERLINK(""x""), hum"'));
    });

    test('recording export has no file paths', () {
      final csv = CsvExport.recordings(
        recordings: [_probe(DateTime(2026, 10, 1))],
        codes: {'p': 'P001'},
      );
      expect(csv, isNot(contains('.vpa')));
      expect(csv.split('\n').first, contains('kind'));
    });
  });

  test('legacy recordings are tagged probe or practice', () {
    final legacy = Recording.fromMap({
      'id': 'old',
      'patientId': 'p',
      'task': 'sustainedPhonation',
      'type': 'baseline',
      'filePath': 'a.wav',
      'durationSec': 4,
      'createdAt': '2026-09-01T10:00:00.000',
      'analysisStatus': 'pending',
    });
    expect(legacy.kind, RecordingKind.probe);
    expect(legacy.task, RecordingTask.sustainedA);

    final practice = Recording.fromMap({
      'id': 'old2',
      'patientId': 'p',
      'task': 'sustainedPhonation',
      'type': 'homePractice',
      'filePath': 'b.wav',
      'durationSec': 4,
      'createdAt': '2026-09-01T10:00:00.000',
      'analysisStatus': 'pending',
    });
    expect(practice.kind, RecordingKind.practice);
  });
}
