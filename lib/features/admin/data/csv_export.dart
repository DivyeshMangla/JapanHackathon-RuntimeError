import '../../auth/domain/user.dart';
import '../../recordings/domain/recording.dart';
import '../../usage/domain/usage_event.dart';

/// Builds research exports. Patients appear only by participant code, never
/// by name or email, and no audio or file paths are included.
abstract final class CsvExport {
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
}
