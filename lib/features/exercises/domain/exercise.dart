/// How the app could confirm an exercise was done on target (research doc
/// 7.4 and 9). Acoustic verification is not implemented; the type decides
/// which targets a therapist can set. [voiceDiary] exercises are confirmed
/// by the patient filling in a voice-use diary entry for the session.
enum VerificationType {
  sustained,
  glide,
  notes,
  loudness,
  checklist,
  voiceDiary,
}

/// Therapist-set targets for an exercise. Unused fields stay null.
class ExerciseTargets {
  const ExerciseTargets({
    this.durationSec,
    this.pitchHz,
    this.toleranceCents,
    this.rangeSemitones,
  });

  final double? durationSec;
  final double? pitchHz;
  final double? toleranceCents;
  final double? rangeSemitones;

  bool get isEmpty =>
      durationSec == null &&
      pitchHz == null &&
      toleranceCents == null &&
      rangeSemitones == null;

  Map<String, Object?> toMap() => {
    'durationSec': durationSec,
    'pitchHz': pitchHz,
    'toleranceCents': toleranceCents,
    'rangeSemitones': rangeSemitones,
  };

  factory ExerciseTargets.fromMap(Map<dynamic, dynamic> map) {
    double? read(String key) => (map[key] as num?)?.toDouble();
    return ExerciseTargets(
      durationSec: read('durationSec'),
      pitchHz: read('pitchHz'),
      toleranceCents: read('toleranceCents'),
      rangeSemitones: read('rangeSemitones'),
    );
  }
}

enum ExerciseStatus { pendingApproval, approved, archived }

/// An entry in the exercise library (research doc 7.4). New and edited
/// exercises need approval before they can be assigned.
class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.program,
    required this.summary,
    required this.steps,
    required this.durationMinutes,
    required this.repetitions,
    this.sessionsPerDay = 1,
    this.verificationType = VerificationType.checklist,
    this.defaultTargets = const ExerciseTargets(),
    this.evidenceSource = '',
    this.programNote = '',
    this.caution = '',
    this.needsInstructions = false,
    this.catalogueOrder,
    this.approvedBy,
    this.approvedAt,
    this.archived = false,
  });

  final String id;
  final String title;

  /// Program family, e.g. "Vocal Function Exercises" or "SOVT".
  final String program;
  final String summary;
  final List<String> steps;
  final int durationMinutes;

  /// Default repetitions per session; therapists can change it per patient.
  final int repetitions;

  /// Default sessions per day; therapists can change it per patient.
  final int sessionsPerDay;
  final VerificationType verificationType;
  final ExerciseTargets defaultTargets;
  final String evidenceSource;

  /// The program's purpose or usage note from the clinical source. It is
  /// stored on each exercise, not per program, so that approving an
  /// exercise also approves the guidance shown with it.
  final String programNote;

  /// A safety note shown to therapists when assigning and to patients with
  /// the instructions. Empty when there is none.
  final String caution;

  /// The exercise depends on clinician-chosen material (syllables, words,
  /// water depth, a care plan), so an assignment must carry instructions.
  final bool needsInstructions;

  /// Position in the clinical source document, which orders programs and
  /// exercises in the library. Null for exercises added in the app.
  final int? catalogueOrder;
  final String? approvedBy;
  final DateTime? approvedAt;

  /// Archived exercises stay readable for history but cannot be assigned.
  final bool archived;

  ExerciseStatus get status {
    if (archived) return ExerciseStatus.archived;
    return approvedAt == null
        ? ExerciseStatus.pendingApproval
        : ExerciseStatus.approved;
  }

  bool get isAssignable => status == ExerciseStatus.approved;

  /// A content change, which clears any approval.
  Exercise revise({
    required String title,
    required String program,
    required String summary,
    required List<String> steps,
    required int durationMinutes,
    required int repetitions,
    required int sessionsPerDay,
    required VerificationType verificationType,
    required ExerciseTargets defaultTargets,
    required String evidenceSource,
    required String programNote,
    required String caution,
    required bool needsInstructions,
  }) => Exercise(
    id: id,
    title: title,
    program: program,
    summary: summary,
    steps: steps,
    durationMinutes: durationMinutes,
    repetitions: repetitions,
    sessionsPerDay: sessionsPerDay,
    verificationType: verificationType,
    defaultTargets: defaultTargets,
    evidenceSource: evidenceSource,
    programNote: programNote,
    caution: caution,
    needsInstructions: needsInstructions,
    catalogueOrder: catalogueOrder,
    archived: archived,
  );

  Exercise approve({required String by, required DateTime at}) =>
      _withReview(approvedBy: by, approvedAt: at, archived: archived);

  Exercise withArchived(bool value) => _withReview(
    approvedBy: approvedBy,
    approvedAt: approvedAt,
    archived: value,
  );

  /// Same content with a different approval or archive state.
  Exercise _withReview({
    required String? approvedBy,
    required DateTime? approvedAt,
    required bool archived,
  }) => Exercise(
    id: id,
    title: title,
    program: program,
    summary: summary,
    steps: steps,
    durationMinutes: durationMinutes,
    repetitions: repetitions,
    sessionsPerDay: sessionsPerDay,
    verificationType: verificationType,
    defaultTargets: defaultTargets,
    evidenceSource: evidenceSource,
    programNote: programNote,
    caution: caution,
    needsInstructions: needsInstructions,
    catalogueOrder: catalogueOrder,
    approvedBy: approvedBy,
    approvedAt: approvedAt,
    archived: archived,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'program': program,
    'summary': summary,
    'steps': steps,
    'durationMinutes': durationMinutes,
    'repetitions': repetitions,
    'sessionsPerDay': sessionsPerDay,
    'verificationType': verificationType.name,
    'defaultTargets': defaultTargets.toMap(),
    'evidenceSource': evidenceSource,
    'programNote': programNote,
    'caution': caution,
    'needsInstructions': needsInstructions,
    'catalogueOrder': catalogueOrder,
    'approvedBy': approvedBy,
    'approvedAt': approvedAt?.toIso8601String(),
    'archived': archived,
  };

  factory Exercise.fromMap(Map<dynamic, dynamic> map) {
    final approvedAt = map['approvedAt'] as String?;
    final targets = map['defaultTargets'] as Map<dynamic, dynamic>?;
    return Exercise(
      id: map['id'] as String,
      title: map['title'] as String,
      // Records written before the research model stored "category".
      program: (map['program'] ?? map['category']) as String,
      summary: map['summary'] as String,
      steps: (map['steps'] as List<dynamic>).cast<String>(),
      durationMinutes: map['durationMinutes'] as int,
      repetitions: map['repetitions'] as int,
      sessionsPerDay: map['sessionsPerDay'] as int? ?? 1,
      verificationType: VerificationType.values.byName(
        map['verificationType'] as String? ?? VerificationType.checklist.name,
      ),
      defaultTargets: targets == null
          ? const ExerciseTargets()
          : ExerciseTargets.fromMap(targets),
      evidenceSource: map['evidenceSource'] as String? ?? '',
      programNote: map['programNote'] as String? ?? '',
      caution: map['caution'] as String? ?? '',
      needsInstructions: map['needsInstructions'] as bool? ?? false,
      catalogueOrder: map['catalogueOrder'] as int?,
      approvedBy: map['approvedBy'] as String?,
      approvedAt: approvedAt == null ? null : DateTime.parse(approvedAt),
      archived: map['archived'] as bool? ?? false,
    );
  }
}

/// Exercises grouped by program, in the clinical source's order: programs
/// by their first catalogued exercise, exercises by catalogue position, and
/// anything added in the app after the catalogued ones, by title.
List<(String, List<Exercise>)> groupByProgram(Iterable<Exercise> exercises) {
  int compare(Exercise a, Exercise b) {
    final x = a.catalogueOrder;
    final y = b.catalogueOrder;
    if (x != null && y != null) return x.compareTo(y);
    if (x != null) return -1;
    if (y != null) return 1;
    return a.title.compareTo(b.title);
  }

  final groups = <String, List<Exercise>>{};
  for (final e in [...exercises]..sort(compare)) {
    groups.putIfAbsent(e.program, () => []).add(e);
  }
  return [for (final MapEntry(:key, :value) in groups.entries) (key, value)];
}
