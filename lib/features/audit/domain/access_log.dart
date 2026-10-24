enum AccessAction { playback, export }

/// One entry in the append-only access log.
class AccessLogEntry {
  const AccessLogEntry({
    required this.at,
    required this.userId,
    required this.userEmail,
    required this.action,
    required this.target,
  });

  final DateTime at;
  final String userId;
  final String userEmail;
  final AccessAction action;

  /// What was accessed, e.g. "P001 recording rec-P001-0" or
  /// "completions.csv".
  final String target;

  Map<String, Object?> toMap() => {
    'at': at.toIso8601String(),
    'userId': userId,
    'userEmail': userEmail,
    'action': action.name,
    'target': target,
  };

  factory AccessLogEntry.fromMap(Map<dynamic, dynamic> map) => AccessLogEntry(
    at: DateTime.parse(map['at'] as String),
    userId: map['userId'] as String,
    userEmail: map['userEmail'] as String,
    action: AccessAction.values.byName(map['action'] as String),
    target: map['target'] as String,
  );
}

/// Append-only by design: there is deliberately no update or delete.
abstract interface class AccessLogRepository {
  Future<void> append(AccessLogEntry entry);

  /// Newest first.
  Future<List<AccessLogEntry>> recent({int limit = 200});
}
