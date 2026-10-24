import '../../auth/domain/user.dart';
import '../../exercises/domain/voice_use_entry.dart';
import '../../questionnaires/domain/questionnaire.dart';
import '../../study/domain/intervention_outcome.dart';
import '../../study/domain/monitoring_entry.dart';
import '../../study/domain/participant_record.dart';
import '../../study/domain/study_outcomes.dart';
import '../../usage/domain/usage_event.dart';
import 'csv_export.dart';

/// Exports for the protocol's data collection instruments, analysis-ready
/// with one row per participant or per response. As with [CsvExport],
/// patients appear only by participant code. Free-text answers are
/// included because the protocol analyses them thematically.
abstract final class StudyCsvExport {
  /// Demographic and Clinical Information Form, consent and enrolment status.
  static String participants({
    required List<ParticipantRecord> records,
    required List<User> patients,
  }) {
    final byPatient = {for (final r in records) r.patientId: r};
    final rows = [...patients]
      ..sort(
        (a, b) => (a.participantCode ?? '').compareTo(b.participantCode ?? ''),
      );
    return CsvExport.table(
      [
        'participant_code',
        'intervention_start',
        'info_sheet_provided',
        'consent_signed_on',
        'orientation_on',
        'age_years',
        'gender',
        'education',
        'occupation',
        'voice_use',
        'primary_language',
        'diagnosis',
        'symptom_months',
        'smoking',
        'laryngoscopy_on',
        'therapy_started_on',
        'clinic_sessions_per_week',
        'other_conditions',
        'status',
        'withdrawn_on',
        'withdrawal_reason',
      ],
      [
        for (final patient in rows)
          _participantRow(
            patient,
            byPatient[patient.id] ??
                ParticipantRecord.undocumented(
                  patientId: patient.id,
                  enrolledOn: patient.createdAt,
                ),
          ),
      ],
    );
  }

  static List<String> _participantRow(User patient, ParticipantRecord r) {
    final d = r.demographics;
    final c = r.clinical;
    return [
      patient.participantCode ?? 'unknown',
      CsvExport.day(r.interventionStart),
      '${r.infoSheetProvided}',
      _optionalDay(r.consentSignedOn),
      _optionalDay(r.orientationOn),
      d == null ? '' : '${d.ageYears}',
      d?.gender.name ?? '',
      d?.education.name ?? '',
      d?.occupation ?? '',
      d?.voiceUse.name ?? '',
      d?.primaryLanguage ?? '',
      c?.diagnosis ?? '',
      c == null ? '' : '${c.symptomMonths}',
      c?.smoking.name ?? '',
      _optionalDay(c?.laryngoscopyOn),
      _optionalDay(c?.therapyStartedOn),
      c?.clinicSessionsPerWeek?.toString() ?? '',
      c?.otherConditions ?? '',
      r.isWithdrawn ? 'withdrawn' : 'enrolled',
      _optionalDay(r.withdrawnOn),
      r.withdrawalReason,
    ];
  }

  /// One row per participant with every outcome measure, plus per-week
  /// adherence and compliance columns for repeated-measures analysis.
  static String outcomes({
    required List<ParticipantOutcome> participants,
    required double threshold,
  }) {
    final weeks = participants.fold<int>(
      0,
      (most, p) =>
          p.outcome.period.weeks > most ? p.outcome.period.weeks : most,
    );
    final rows = [...participants]..sort((a, b) => a.code.compareTo(b.code));
    return CsvExport.table(
      [
        'participant_code',
        'status',
        'intervention_start',
        'intervention_end',
        'scored_through',
        'sessions_prescribed',
        'sessions_completed',
        'adherence_pct',
        'prescribed_days',
        'full_dose_days',
        'compliance_pct',
        'practice_days',
        'at_or_above_threshold',
        'used_app_every_week',
        'baseline_selfreport_days',
        'final_week_selfreport_days',
        'sus_score',
        'satisfaction_mean',
        for (var w = 1; w <= weeks; w++) ...[
          'week${w}_adherence_pct',
          'week${w}_compliance_pct',
        ],
      ],
      [
        for (final p in rows)
          [
            p.code,
            p.record.isWithdrawn ? 'withdrawn' : 'enrolled',
            CsvExport.day(p.outcome.period.start),
            CsvExport.day(p.outcome.period.end),
            _optionalDay(p.outcome.scoredThrough),
            '${p.outcome.sessionsDue}',
            '${p.outcome.sessionsDone}',
            _percent(p.outcome.adherence),
            '${p.outcome.prescribedDays}',
            '${p.outcome.fullDoseDays}',
            _percent(p.outcome.compliance),
            '${p.outcome.practiceDays}',
            switch (p.outcome.adherence) {
              null => '',
              final rate => '${rate >= threshold}',
            },
            '${p.outcome.usedEveryWeek}',
            p.questionnaires.baseline?.daysPractised.toString() ?? '',
            p.questionnaires
                    .reportForWeek(p.outcome.period.weeks)
                    ?.daysPractised
                    .toString() ??
                '',
            p.susScore?.toStringAsFixed(1) ?? '',
            p.satisfaction?.toStringAsFixed(2) ?? '',
            for (var w = 1; w <= weeks; w++) ...[
              _percent(_week(p, w)?.adherence),
              _percent(_week(p, w)?.compliance),
            ],
          ],
      ],
    );
  }

  /// Participant self-report records (week 0 is the baseline assessment).
  static String selfReports({
    required List<AdherenceSelfReport> reports,
    required Map<String, String> codes,
  }) => CsvExport.table(
    [
      'participant_code',
      'week',
      'submitted_at',
      'days_practised',
      'main_barrier',
      'note',
    ],
    [
      for (final r in _byCode(reports, codes, (r) => r.patientId))
        [
          codes[r.patientId] ?? 'unknown',
          '${r.week}',
          r.submittedAt.toIso8601String(),
          '${r.daysPractised}',
          r.barrier.name,
          r.note,
        ],
    ],
  );

  /// Adherence and Compliance Monitoring Forms.
  static String monitoring({
    required List<MonitoringEntry> entries,
    required Map<String, String> codes,
  }) => CsvExport.table(
    [
      'participant_code',
      'week',
      'recorded_at',
      'recorded_by',
      'practice',
      'schedule',
      'technique',
      'barriers',
      'notes',
    ],
    [
      for (final e in _byCode(entries, codes, (e) => e.patientId))
        [
          codes[e.patientId] ?? 'unknown',
          '${e.week}',
          e.recordedAt.toIso8601String(),
          e.therapistId,
          e.practice.name,
          e.schedule.name,
          e.technique.name,
          e.barriers,
          e.notes,
        ],
    ],
  );

  /// Usability Feedback Questionnaire: item answers and the SUS score.
  static String usability({
    required List<UsabilityResponse> responses,
    required Map<String, String> codes,
  }) => CsvExport.table(
    [
      'participant_code',
      'submitted_at',
      for (var i = 1; i <= UsabilityResponse.itemCount; i++) 'sus_$i',
      'sus_score',
    ],
    [
      for (final r in _byCode(responses, codes, (r) => r.patientId))
        [
          codes[r.patientId] ?? 'unknown',
          r.submittedAt.toIso8601String(),
          for (final answer in r.answers) '$answer',
          r.score.toStringAsFixed(1),
        ],
    ],
  );

  /// Structured satisfaction feedback with the open comments.
  static String feedback({
    required List<SatisfactionResponse> responses,
    required Map<String, String> codes,
  }) => CsvExport.table(
    [
      'participant_code',
      'submitted_at',
      for (final item in SatisfactionItem.values) _snake(item.name),
      'mean_rating',
      'liked_most',
      'difficulties',
      'suggestions',
    ],
    [
      for (final r in _byCode(responses, codes, (r) => r.patientId))
        [
          codes[r.patientId] ?? 'unknown',
          r.submittedAt.toIso8601String(),
          for (final item in SatisfactionItem.values) '${r.ratings[item]}',
          r.meanRating.toStringAsFixed(2),
          r.likedMost,
          r.difficulties,
          r.suggestions,
        ],
    ],
  );

  /// Voice-use monitoring diary: speaking time band, fatigue 0-10 and the
  /// situations that increased vocal effort, as space-separated names.
  static String voiceDiary({
    required List<VoiceUseEntry> entries,
    required Map<String, String> codes,
  }) => CsvExport.table(
    [
      'participant_code',
      'day',
      'logged_at',
      'speaking_time',
      'fatigue_0_10',
      'situations',
      'note',
    ],
    [
      for (final e in _byCode(entries, codes, (e) => e.patientId))
        [
          codes[e.patientId] ?? 'unknown',
          CsvExport.day(e.day),
          e.loggedAt.toIso8601String(),
          _snake(e.speakingTime.name),
          '${e.fatigue}',
          [for (final s in e.situations) _snake(s.name)].join(' '),
          e.note,
        ],
    ],
  );

  /// Application Usage Log, oldest first.
  static String usageLog({
    required List<UsageEvent> events,
    required Map<String, String> codes,
  }) => CsvExport.table(
    ['participant_code', 'at', 'action', 'detail'],
    [
      for (final e in events)
        [
          codes[e.patientId] ?? 'unknown',
          e.at.toIso8601String(),
          e.action.name,
          e.detail,
        ],
    ],
  );

  /// Orders rows by participant code. [List.sort] is not stable, so the
  /// original position breaks ties and each participant's rows keep their
  /// repository order.
  static List<T> _byCode<T>(
    List<T> items,
    Map<String, String> codes,
    String Function(T) patientOf,
  ) {
    final indexed = items.indexed.toList()
      ..sort((a, b) {
        final byCode = (codes[patientOf(a.$2)] ?? '').compareTo(
          codes[patientOf(b.$2)] ?? '',
        );
        return byCode != 0 ? byCode : a.$1.compareTo(b.$1);
      });
    return [for (final (_, item) in indexed) item];
  }

  static WeekOutcome? _week(ParticipantOutcome p, int week) =>
      p.outcome.weeks.where((w) => w.week == week).firstOrNull;

  static String _optionalDay(DateTime? day) =>
      day == null ? '' : CsvExport.day(day);

  static String _percent(double? rate) =>
      rate == null ? '' : (rate * 100).toStringAsFixed(1);

  static String _snake(String camel) =>
      camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}
