import '../../recordings/domain/recording.dart';

/// One seeded voice sample: which patient, what it is, and when it was made
/// relative to enrolment.
typedef DemoRecording = ({
  String participantCode,
  double pitchHz,
  RecordingKind kind,
  RecordingType type,
  RecordingTask task,
  int dayOffset,
  double seconds,
});

/// Part of a baseline probe for everyone, one practice take, and part of a
/// follow-up probe, with fewer later samples for the patients with low
/// adherence. Full 17-take probe sets are not seeded to keep installs small.
List<DemoRecording> demoRecordings() {
  const voices = {
    'P001': 205.0,
    'P002': 118.0,
    'P003': 196.0,
    'P004': 112.0,
    'P005': 214.0,
  };
  return [
    for (final MapEntry(key: code, value: pitch) in voices.entries) ...[
      (
        participantCode: code,
        pitchHz: pitch,
        kind: RecordingKind.probe,
        type: RecordingType.baseline,
        task: RecordingTask.sustainedA,
        dayOffset: 0,
        seconds: 4.0,
      ),
      (
        participantCode: code,
        pitchHz: pitch,
        kind: RecordingKind.probe,
        type: RecordingType.baseline,
        task: RecordingTask.readingPassage,
        dayOffset: 0,
        seconds: 6.0,
      ),
      if (code != 'P003' && code != 'P005')
        (
          participantCode: code,
          pitchHz: pitch,
          kind: RecordingKind.practice,
          type: RecordingType.homePractice,
          task: RecordingTask.sustainedPhonation,
          dayOffset: 7,
          seconds: 4.0,
        ),
      if (code != 'P005')
        (
          participantCode: code,
          pitchHz: pitch,
          kind: RecordingKind.probe,
          type: RecordingType.followUp,
          task: RecordingTask.spontaneousSpeech,
          dayOffset: 14,
          seconds: 5.0,
        ),
    ],
  ];
}
