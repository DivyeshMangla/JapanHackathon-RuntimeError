/// Patient actions recorded in the Application Usage Log.
enum UsageAction {
  signIn,
  signOut,
  exerciseOpened,
  educationOpened,
  sessionMarked,
  sessionUndone,
  recordingSaved,
  remindersChanged,
}

/// One entry in a participant's application usage log. [detail] names what
/// was used (an exercise id, a topic, a recording task), never free text the
/// patient typed.
class UsageEvent {
  const UsageEvent({
    required this.at,
    required this.patientId,
    required this.action,
    this.detail = '',
  });

  final DateTime at;
  final String patientId;
  final UsageAction action;
  final String detail;

  Map<String, Object?> toMap() => {
    'at': at.toIso8601String(),
    'patientId': patientId,
    'action': action.name,
    'detail': detail,
  };

  factory UsageEvent.fromMap(Map<dynamic, dynamic> map) => UsageEvent(
    at: DateTime.parse(map['at'] as String),
    patientId: map['patientId'] as String,
    action: UsageAction.values.byName(map['action'] as String),
    detail: map['detail'] as String? ?? '',
  );
}

/// Append-only, like the access log.
abstract interface class UsageLogRepository {
  Future<void> append(UsageEvent event);

  /// Newest first.
  Future<List<UsageEvent>> forPatient(String patientId);

  /// Oldest first, for export.
  Future<List<UsageEvent>> all();
}
