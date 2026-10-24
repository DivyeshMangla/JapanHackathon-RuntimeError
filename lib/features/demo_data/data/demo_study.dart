import '../../../core/utils/dates.dart';
import '../../exercises/domain/completion.dart';
import '../../questionnaires/domain/questionnaire.dart';
import '../../recordings/domain/recording.dart';
import '../../study/domain/monitoring_entry.dart';
import '../../study/domain/participant_record.dart';
import '../../usage/domain/usage_event.dart';
import 'demo_program.dart';

/// Demo study data for the protocol's data collection instruments. Values
/// are invented for demonstration and describe no real person.

/// The participant who has already finished the four-week intervention, so
/// follow-up questionnaires and the post-intervention probe are due.
const completedPatientId = 'patient-P006';
const completedPatientCode = 'P006';
const completedPatientName = 'Ravi Menon';
const completedPatientTherapist = 'therapist-02';

/// Days before today that P006 started using the app.
const completedStartOffset = 29;

typedef _Profile = ({
  Demographics demographics,
  ClinicalDetails clinical,
  int baselineDays,
  PracticeBarrier baselineBarrier,
});

const _profiles = <String, _Profile>{
  'patient-P001': (
    demographics: Demographics(
      ageYears: 34,
      gender: Gender.female,
      education: EducationLevel.postgraduate,
      occupation: 'Secondary school teacher',
      voiceUse: VoiceUseLevel.professionalVocal,
      primaryLanguage: 'English',
    ),
    clinical: ClinicalDetails(
      diagnosis: 'Bilateral vocal fold nodules',
      symptomMonths: 8,
      smoking: SmokingStatus.never,
      clinicSessionsPerWeek: 1,
    ),
    baselineDays: 4,
    baselineBarrier: PracticeBarrier.noTime,
  ),
  'patient-P002': (
    demographics: Demographics(
      ageYears: 46,
      gender: Gender.male,
      education: EducationLevel.graduate,
      occupation: 'Call centre supervisor',
      voiceUse: VoiceUseLevel.professionalVocal,
      primaryLanguage: 'English',
    ),
    clinical: ClinicalDetails(
      diagnosis: 'Muscle tension dysphonia',
      symptomMonths: 14,
      smoking: SmokingStatus.former,
      clinicSessionsPerWeek: 1,
      otherConditions: 'Laryngopharyngeal reflux',
    ),
    baselineDays: 3,
    baselineBarrier: PracticeBarrier.forgot,
  ),
  'patient-P003': (
    demographics: Demographics(
      ageYears: 29,
      gender: Gender.female,
      education: EducationLevel.graduate,
      occupation: 'Singer and music tutor',
      voiceUse: VoiceUseLevel.eliteVocal,
      primaryLanguage: 'English',
    ),
    clinical: ClinicalDetails(
      diagnosis: 'Vocal fold polyp, left',
      symptomMonths: 5,
      smoking: SmokingStatus.never,
      clinicSessionsPerWeek: 2,
    ),
    baselineDays: 2,
    baselineBarrier: PracticeBarrier.unsureHow,
  ),
  'patient-P004': (
    demographics: Demographics(
      ageYears: 58,
      gender: Gender.male,
      education: EducationLevel.secondary,
      occupation: 'Shop owner',
      voiceUse: VoiceUseLevel.nonVocalProfessional,
      primaryLanguage: 'English',
    ),
    clinical: ClinicalDetails(
      diagnosis: 'Presbyphonia',
      symptomMonths: 20,
      smoking: SmokingStatus.current,
      clinicSessionsPerWeek: 1,
    ),
    baselineDays: 3,
    baselineBarrier: PracticeBarrier.forgot,
  ),
  'patient-P005': (
    demographics: Demographics(
      ageYears: 41,
      gender: Gender.female,
      education: EducationLevel.higherSecondary,
      occupation: 'Homemaker',
      voiceUse: VoiceUseLevel.nonVocalNonProfessional,
      primaryLanguage: 'English',
    ),
    clinical: ClinicalDetails(
      diagnosis: 'Functional dysphonia',
      symptomMonths: 3,
      smoking: SmokingStatus.never,
    ),
    baselineDays: 1,
    baselineBarrier: PracticeBarrier.voiceDiscomfort,
  ),
  completedPatientId: (
    demographics: Demographics(
      ageYears: 37,
      gender: Gender.male,
      education: EducationLevel.graduate,
      occupation: 'Sales representative',
      voiceUse: VoiceUseLevel.professionalVocal,
      primaryLanguage: 'English',
    ),
    clinical: ClinicalDetails(
      diagnosis: 'Muscle tension dysphonia',
      symptomMonths: 10,
      smoking: SmokingStatus.never,
      clinicSessionsPerWeek: 1,
    ),
    baselineDays: 2,
    baselineBarrier: PracticeBarrier.noTime,
  ),
};

/// A complete study record for each demo patient, except that P005 has not
/// had the app orientation yet, so the baseline checklist shows a gap.
List<ParticipantRecord> demoParticipantRecords(Map<String, DateTime> starts) =>
    [
      for (final MapEntry(key: patientId, value: start) in starts.entries)
        if (_profiles[patientId] case final profile?)
          ParticipantRecord(
            patientId: patientId,
            interventionStart: start,
            infoSheetProvided: true,
            consentSignedOn: addDays(start, -2),
            demographics: profile.demographics,
            clinical: ClinicalDetails(
              diagnosis: profile.clinical.diagnosis,
              symptomMonths: profile.clinical.symptomMonths,
              smoking: profile.clinical.smoking,
              clinicSessionsPerWeek: profile.clinical.clinicSessionsPerWeek,
              otherConditions: profile.clinical.otherConditions,
              laryngoscopyOn: addDays(start, -21),
              therapyStartedOn: addDays(start, -7),
            ),
            orientationOn: patientId == 'patient-P005' ? null : start,
          ),
    ];

/// Baseline reports for everyone, plus weekly reports for the weeks each
/// patient has finished: P001, P002 and P004 reported week 1, and P006
/// reported all four weeks.
List<AdherenceSelfReport> demoSelfReports(Map<String, DateTime> starts) {
  const weekly = <String, List<(int, PracticeBarrier)>>{
    'patient-P001': [(7, PracticeBarrier.none)],
    'patient-P002': [(5, PracticeBarrier.forgot)],
    'patient-P004': [(5, PracticeBarrier.noTime)],
    completedPatientId: [
      (6, PracticeBarrier.none),
      (6, PracticeBarrier.noTime),
      (5, PracticeBarrier.forgot),
      (6, PracticeBarrier.none),
    ],
  };
  return [
    for (final MapEntry(key: patientId, value: start) in starts.entries)
      if (_profiles[patientId] case final profile?) ...[
        AdherenceSelfReport(
          id: 'self-$patientId-0',
          patientId: patientId,
          week: AdherenceSelfReport.baselineWeek,
          submittedAt: addDays(start, -1).add(const Duration(hours: 11)),
          daysPractised: profile.baselineDays,
          barrier: profile.baselineBarrier,
        ),
        for (final (index, (days, barrier))
            in (weekly[patientId] ?? const <(int, PracticeBarrier)>[]).indexed)
          AdherenceSelfReport(
            id: 'self-$patientId-${index + 1}',
            patientId: patientId,
            week: index + 1,
            submittedAt: addDays(
              start,
              7 * (index + 1) - 1,
            ).add(const Duration(hours: 20)),
            daysPractised: days,
            barrier: barrier,
          ),
      ],
  ];
}

/// Week 1 monitoring forms for four patients, and every week for P006.
List<MonitoringEntry> demoMonitoring(Map<String, DateTime> starts) {
  MonitoringEntry entry(
    String patientId,
    int week,
    MonitoringRating practice,
    MonitoringRating schedule, {
    String barriers = '',
    String notes = '',
  }) {
    final start = starts[patientId]!;
    return MonitoringEntry(
      id: 'monitor-$patientId-$week',
      patientId: patientId,
      therapistId:
          patientId == 'patient-P004' ||
              patientId == 'patient-P005' ||
              patientId == completedPatientId
          ? 'therapist-02'
          : 'therapist-01',
      week: week,
      recordedAt: addDays(start, 7 * week).add(const Duration(hours: 15)),
      practice: practice,
      schedule: schedule,
      technique: MonitoringRating.mostly,
      barriers: barriers,
      notes: notes,
    );
  }

  const fully = MonitoringRating.fully;
  const mostly = MonitoringRating.mostly;
  const partly = MonitoringRating.partly;
  return [
    if (starts.containsKey('patient-P001'))
      entry('patient-P001', 1, fully, fully, notes: 'Practising before work.'),
    if (starts.containsKey('patient-P002'))
      entry('patient-P002', 1, mostly, partly, barriers: 'Late shifts.'),
    if (starts.containsKey('patient-P003'))
      entry(
        'patient-P003',
        1,
        partly,
        partly,
        barriers: 'Unsure about lip trill technique.',
        notes: 'Demonstrated again in clinic.',
      ),
    if (starts.containsKey('patient-P004'))
      entry('patient-P004', 1, mostly, mostly),
    if (starts.containsKey(completedPatientId))
      for (var week = 1; week <= 4; week++)
        entry(completedPatientId, week, week == 3 ? mostly : fully, mostly),
  ];
}

/// P006's baseline, weekly follow-up and one practice recording. The
/// post-intervention probe is left for the demo user to record.
List<DemoRecording> completedPatientRecordings() => [
  for (final (kind, type, task, day) in const [
    (RecordingKind.probe, RecordingType.baseline, RecordingTask.sustainedA, 0),
    (
      RecordingKind.probe,
      RecordingType.baseline,
      RecordingTask.readingPassage,
      0,
    ),
    (
      RecordingKind.practice,
      RecordingType.homePractice,
      RecordingTask.sustainedPhonation,
      10,
    ),
    (RecordingKind.probe, RecordingType.followUp, RecordingTask.sustainedA, 14),
    (RecordingKind.probe, RecordingType.followUp, RecordingTask.sustainedA, 21),
  ])
    (
      participantCode: completedPatientCode,
      pitchHz: 124,
      kind: kind,
      type: type,
      task: task,
      dayOffset: day,
      seconds: 4.0,
    ),
];

/// A plausible usage log: a sign-in on each day with practice, then one
/// event per completed session, plus a first look at the app guide.
List<UsageEvent> demoUsage(
  Iterable<Completion> completions,
  Map<String, DateTime> starts,
) {
  final byDay = <(String, DateTime), List<Completion>>{};
  for (final c in completions) {
    if (!starts.containsKey(c.patientId)) continue;
    byDay.putIfAbsent((c.patientId, c.day), () => []).add(c);
  }
  final events = <UsageEvent>[
    for (final MapEntry(key: patientId, value: start) in starts.entries)
      UsageEvent(
        at: start.add(const Duration(hours: 10)),
        patientId: patientId,
        action: UsageAction.educationOpened,
        detail: 'usingTheApp',
      ),
  ];
  for (final MapEntry(key: (patientId, _), value: sessions) in byDay.entries) {
    sessions.sort((a, b) => a.completedAt.compareTo(b.completedAt));
    events
      ..add(
        UsageEvent(
          at: sessions.first.completedAt.subtract(const Duration(minutes: 6)),
          patientId: patientId,
          action: UsageAction.signIn,
        ),
      )
      ..addAll([
        for (final s in sessions)
          UsageEvent(
            at: s.completedAt,
            patientId: patientId,
            action: UsageAction.sessionMarked,
            detail: s.exerciseId,
          ),
      ]);
  }
  return events..sort((a, b) => a.at.compareTo(b.at));
}
