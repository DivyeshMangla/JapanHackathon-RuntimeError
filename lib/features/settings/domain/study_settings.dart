/// Study-wide settings an admin controls.
class StudySettings {
  const StudySettings({this.probeIntervalDays = 7, this.studyWeeks = 4});

  /// Days between probe recordings after the baseline. Weekly by default
  /// (research doc 8.1).
  final int probeIntervalDays;

  /// Length of the study, which bounds the probe schedule.
  final int studyWeeks;

  StudySettings copyWith({int? probeIntervalDays, int? studyWeeks}) =>
      StudySettings(
        probeIntervalDays: probeIntervalDays ?? this.probeIntervalDays,
        studyWeeks: studyWeeks ?? this.studyWeeks,
      );

  Map<String, Object?> toMap() => {
    'probeIntervalDays': probeIntervalDays,
    'studyWeeks': studyWeeks,
  };

  factory StudySettings.fromMap(Map<dynamic, dynamic> map) => StudySettings(
    probeIntervalDays: map['probeIntervalDays'] as int,
    studyWeeks: map['studyWeeks'] as int,
  );
}

abstract interface class SettingsRepository {
  Future<StudySettings> load();

  Future<void> save(StudySettings settings);
}
