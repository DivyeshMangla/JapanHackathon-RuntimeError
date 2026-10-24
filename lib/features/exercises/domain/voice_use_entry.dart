/// Roughly how long the patient spoke that day. Bands rather than an exact
/// figure, because people cannot recall speaking time precisely.
enum SpeakingTime {
  underOneHour,
  oneToTwoHours,
  twoToFourHours,
  fourToSixHours,
  overSixHours,
}

/// Situations that made the voice work harder that day.
enum VoiceSituation {
  phoneCalls,
  noisyPlaces,
  workSpeaking,
  longConversations,
  singing,
  other,
}

/// One voice-use monitoring entry: the record the vocal hygiene exercise
/// "Voice-use monitoring" asks the patient to keep. Each entry is one
/// completed session of that exercise.
class VoiceUseEntry {
  VoiceUseEntry({
    required this.id,
    required this.patientId,
    required this.day,
    required this.loggedAt,
    required this.speakingTime,
    required this.fatigue,
    required Set<VoiceSituation> situations,
    this.note = '',
  }) : situations = Set.unmodifiable(situations) {
    if (fatigue < 0 || fatigue > maxFatigue) {
      throw ArgumentError.value(fatigue, 'fatigue', 'must be 0-$maxFatigue');
    }
  }

  static const maxFatigue = 10;

  final String id;
  final String patientId;

  /// The calendar day described, with no time component.
  final DateTime day;
  final DateTime loggedAt;
  final SpeakingTime speakingTime;

  /// Vocal fatigue from 0 (none) to 10 (worst imaginable).
  final int fatigue;

  /// Empty when nothing made speaking harder.
  final Set<VoiceSituation> situations;
  final String note;

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'day': day.toIso8601String(),
    'loggedAt': loggedAt.toIso8601String(),
    'speakingTime': speakingTime.name,
    'fatigue': fatigue,
    'situations': [for (final s in situations) s.name],
    'note': note,
  };

  factory VoiceUseEntry.fromMap(Map<dynamic, dynamic> map) => VoiceUseEntry(
    id: map['id'] as String,
    patientId: map['patientId'] as String,
    day: DateTime.parse(map['day'] as String),
    loggedAt: DateTime.parse(map['loggedAt'] as String),
    speakingTime: SpeakingTime.values.byName(map['speakingTime'] as String),
    fatigue: map['fatigue'] as int,
    situations: {
      for (final name in (map['situations'] as List<dynamic>).cast<String>())
        VoiceSituation.values.byName(name),
    },
    note: map['note'] as String? ?? '',
  );
}

abstract interface class VoiceDiaryRepository {
  /// Oldest first.
  Future<List<VoiceUseEntry>> forPatient(String patientId);

  /// Every patient's entries, for export.
  Future<List<VoiceUseEntry>> all();

  Future<void> save(VoiceUseEntry entry);

  Future<void> delete(String id);
}
