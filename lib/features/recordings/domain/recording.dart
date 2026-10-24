/// Practice audio supports exercise work; probe recordings are the identical
/// standard tasks used to judge status (research doc 8.1).
enum RecordingKind { practice, probe }

enum RecordingTask {
  // Free-choice practice tasks.
  sustainedPhonation('sustained-phonation'),
  readingPassage('reading-passage'),
  spontaneousSpeech('spontaneous-speech'),

  // Probe-only tasks (research doc section 14).
  sustainedA('sustained-a'),
  maximumA('maximum-a'),
  sustainedS('sustained-s'),
  sustainedZ('sustained-z'),
  vowelA('vowel-a'),
  vowelI('vowel-i'),
  vowelU('vowel-u'),
  pitchGlide('pitch-glide');

  const RecordingTask(this.slug);

  /// Used in file names.
  final String slug;

  static const practiceTasks = [
    sustainedPhonation,
    readingPassage,
    spontaneousSpeech,
  ];
}

enum RecordingType {
  baseline('baseline'),
  followUp('follow-up'),
  homePractice('home-practice');

  const RecordingType(this.slug);

  /// Used in file names.
  final String slug;
}

enum AnalysisStatus { pending }

class Recording {
  const Recording({
    required this.id,
    required this.patientId,
    required this.kind,
    required this.task,
    required this.type,
    required this.durationSec,
    required this.createdAt,
    this.trial = 1,
    this.probeSessionId,
    this.analysisStatus = AnalysisStatus.pending,
  });

  final String id;
  final String patientId;
  final RecordingKind kind;
  final RecordingTask task;
  final RecordingType type;

  final double durationSec;
  final DateTime createdAt;

  /// Repetition number within a probe task, starting at 1.
  final int trial;

  /// Groups the recordings of one probe session.
  final String? probeSessionId;
  final AnalysisStatus analysisStatus;

  /// Recordings are identified by id, so they can key provider families.
  @override
  bool operator ==(Object other) => other is Recording && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'kind': kind.name,
    'task': task.name,
    'type': type.name,
    'durationSec': durationSec,
    'createdAt': createdAt.toIso8601String(),
    'trial': trial,
    'probeSessionId': probeSessionId,
    'analysisStatus': analysisStatus.name,
  };

  factory Recording.fromMap(Map<dynamic, dynamic> map) {
    final type = RecordingType.values.byName(map['type'] as String);
    var task = RecordingTask.values.byName(map['task'] as String);
    final storedKind = map['kind'] as String?;
    // Records from before probes existed: anything other than home practice
    // was a status recording, and its sustained tone was the probe /a/.
    final kind = storedKind != null
        ? RecordingKind.values.byName(storedKind)
        : type == RecordingType.homePractice
        ? RecordingKind.practice
        : RecordingKind.probe;
    if (storedKind == null &&
        kind == RecordingKind.probe &&
        task == RecordingTask.sustainedPhonation) {
      task = RecordingTask.sustainedA;
    }
    return Recording(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      kind: kind,
      task: task,
      type: type,
      durationSec: (map['durationSec'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      trial: map['trial'] as int? ?? 1,
      probeSessionId: map['probeSessionId'] as String?,
      analysisStatus: AnalysisStatus.values.byName(
        map['analysisStatus'] as String,
      ),
    );
  }
}
