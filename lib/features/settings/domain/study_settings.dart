/// Study-wide settings an admin controls.
class StudySettings {
  const StudySettings({
    this.adherenceThreshold = 0.8,
    this.probeIntervalDays = 7,
    this.studyWeeks = 4,
  });

  /// Share of prescribed sessions that counts as "high" adherence. The
  /// research doc's provisional cut-off is 80% (section 8.3).
  final double adherenceThreshold;

  /// Days between probe recordings after the baseline. Weekly by default
  /// (research doc 8.1).
  final int probeIntervalDays;

  /// Length of the study, which bounds the probe schedule.
  final int studyWeeks;

  StudySettings copyWith({
    double? adherenceThreshold,
    int? probeIntervalDays,
    int? studyWeeks,
  }) => StudySettings(
    adherenceThreshold: adherenceThreshold ?? this.adherenceThreshold,
    probeIntervalDays: probeIntervalDays ?? this.probeIntervalDays,
    studyWeeks: studyWeeks ?? this.studyWeeks,
  );

  Map<String, Object?> toMap() => {
    'adherenceThreshold': adherenceThreshold,
    'probeIntervalDays': probeIntervalDays,
    'studyWeeks': studyWeeks,
  };

  factory StudySettings.fromMap(Map<dynamic, dynamic> map) => StudySettings(
    adherenceThreshold: (map['adherenceThreshold'] as num).toDouble(),
    probeIntervalDays: map['probeIntervalDays'] as int,
    studyWeeks: map['studyWeeks'] as int,
  );
}

abstract interface class SettingsRepository {
  Future<StudySettings> load();

  Future<void> save(StudySettings settings);
}
