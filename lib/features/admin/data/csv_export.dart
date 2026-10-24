import '../../auth/domain/user.dart';
import '../../exercises/domain/completion.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/schedule.dart';
import '../../exercises/domain/voice_use_entry.dart';
import '../../recordings/domain/recording.dart';
import '../../usage/domain/usage_event.dart';

/// Builds research exports. Patients appear only by participant code, never
/// by name or email, and no audio or file paths are included.
abstract final class CsvExport {
  static String completions({
    required List<Completion> completions,
    required Map<String, String> codes,
    required Map<String, Exercise> exercises,
  }) {
    final rows = [...completions]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    return table(
      ['participant_code', 'exercise_id', 'exercise', 'day', 'completed_at'],
      [
        for (final c in rows)
          [
            codes[c.patientId] ?? 'unknown',
            c.exerciseId,
            exercises[c.exerciseId]?.title ?? '',
            day(c.day),
            c.completedAt.toIso8601String(),
          ],
      ],
    );
  }

  static String assignments({
    required List<Schedule> schedules,
    required Map<String, String> codes,
    required Map<String, Exercise> exercises,
  }) {
    final rows = [...schedules]
      ..sort((a, b) {
        final byCode = (codes[a.patientId] ?? '').compareTo(
          codes[b.patientId] ?? '',
        );
        return byCode != 0
            ? byCode
            : a.effectiveFrom.compareTo(b.effectiveFrom);
      });
    return table(
      [
        'participant_code',
        'assignment_version_id',
        'exercise_id',
        'exercise',
        'program',
        'weekdays',
        'sessions_per_day',
        'repetitions',
        'target_duration_s',
        'target_pitch_hz',
        'target_tolerance_cents',
        'target_range_semitones',
        'instructions',
        'effective_from',
        'effective_to',
        'assigned_by',
      ],
      [
        for (final s in rows)
          [
            codes[s.patientId] ?? 'unknown',
            s.id,
            s.exerciseId,
            exercises[s.exerciseId]?.title ?? '',
            exercises[s.exerciseId]?.program ?? '',
            (s.weekdays.toList()..sort()).join(' '),
            '${s.sessionsPerDay}',
            '${s.repetitions}',
            _number(s.targets.durationSec),
            _number(s.targets.pitchHz),
            _number(s.targets.toleranceCents),
            _number(s.targets.rangeSemitones),
            s.instructions,
            day(s.effectiveFrom),
            s.effectiveTo == null ? '' : day(s.effectiveTo!),
            s.assignedBy ?? '',
          ],
      ],
    );
  }

  static String recordings({
    required List<Recording> recordings,
    required Map<String, String> codes,
  }) {
    return table(
      [
        'participant_code',
        'recording_id',
        'kind',
        'task',
        'type',
        'trial',
        'probe_session_id',
        'duration_s',
        'created_at',
        'analysis_status',
      ],
      [
        for (final r in recordings)
          [
            codes[r.patientId] ?? 'unknown',
            r.id,
            r.kind.name,
            r.task.name,
            r.type.name,
            '${r.trial}',
            r.probeSessionId ?? '',
            r.durationSec.toStringAsFixed(2),
            r.createdAt.toIso8601String(),
            r.analysisStatus.name,
          ],
      ],
    );
  }

  static String voiceDiary({
    required List<VoiceUseEntry> entries,
    required Map<String, String> codes,
  }) => table(
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
          day(e.day),
          e.loggedAt.toIso8601String(),
          _snake(e.speakingTime.name),
          '${e.fatigue}',
          [for (final s in e.situations) _snake(s.name)].join(' '),
          e.note,
        ],
    ],
  );

  /// Application usage log, oldest first.
  static String usageLog({
    required List<UsageEvent> events,
    required Map<String, String> codes,
  }) => table(
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

  static String _snake(String camel) =>
      camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  /// Patient id to participant code, the only patient identifier exported.
  static Map<String, String> participantCodes(Iterable<User> patients) => {
    for (final p in patients) p.id: p.participantCode ?? 'unknown',
  };

  /// A CSV document from [header] and [rows], with every cell made safe.
  static String table(List<String> header, List<List<String>> rows) {
    final buffer = StringBuffer()..writeln(header.map(_cell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_cell).join(','));
    }
    return buffer.toString();
  }

  /// Quotes cells that need it, and defuses values a spreadsheet would treat
  /// as a formula.
  static String _cell(String value) {
    var v = value;
    if (v.isNotEmpty && '=+-@'.contains(v[0]) && double.tryParse(v) == null) {
      v = "'$v";
    }
    if (v.contains(RegExp('[",\r\n]'))) {
      v = '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  /// ISO calendar date, e.g. 2026-10-05.
  static String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _number(double? v) => v == null ? '' : '$v';
}
