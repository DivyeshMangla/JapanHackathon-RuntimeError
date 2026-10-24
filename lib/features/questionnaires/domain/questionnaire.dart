/// Main reason given for missed practice in a self-report.
enum PracticeBarrier {
  none,
  forgot,
  noTime,
  voiceDiscomfort,
  unsureHow,
  feltBetter,
  other,
}

/// Participant self-report record of home practice: the baseline adherence
/// assessment (week 0, before app use) and one report per study week.
class AdherenceSelfReport {
  const AdherenceSelfReport({
    required this.id,
    required this.patientId,
    required this.week,
    required this.submittedAt,
    required this.daysPractised,
    required this.barrier,
    this.note = '',
  });

  static const baselineWeek = 0;

  final String id;
  final String patientId;

  /// 0 for the baseline report, otherwise the 1-based study week.
  final int week;
  final DateTime submittedAt;

  /// Days in the previous seven on which the participant did their voice
  /// exercises, 0 to 7.
  final int daysPractised;
  final PracticeBarrier barrier;
  final String note;

  bool get isBaseline => week == baselineWeek;

  /// Self-reported practice days as a share of the week.
  double get rate => daysPractised / 7;

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'week': week,
    'submittedAt': submittedAt.toIso8601String(),
    'daysPractised': daysPractised,
    'barrier': barrier.name,
    'note': note,
  };

  factory AdherenceSelfReport.fromMap(Map<dynamic, dynamic> map) =>
      AdherenceSelfReport(
        id: map['id'] as String,
        patientId: map['patientId'] as String,
        week: map['week'] as int,
        submittedAt: DateTime.parse(map['submittedAt'] as String),
        daysPractised: map['daysPractised'] as int,
        barrier: PracticeBarrier.values.byName(map['barrier'] as String),
        note: map['note'] as String? ?? '',
      );
}

/// The System Usability Scale (Brooke, 1996): ten items answered from 1
/// (strongly disagree) to 5 (strongly agree), with "system" read as "app".
class UsabilityResponse {
  UsabilityResponse({
    required this.id,
    required this.patientId,
    required this.submittedAt,
    required List<int> answers,
  }) : answers = List.unmodifiable(answers) {
    if (answers.length != itemCount || answers.any((a) => a < 1 || a > 5)) {
      throw ArgumentError.value(answers, 'answers', 'needs ten answers 1-5');
    }
  }

  static const itemCount = 10;

  final String id;
  final String patientId;
  final DateTime submittedAt;
  final List<int> answers;

  /// Standard SUS scoring, 0 to 100. Odd items are positively worded and
  /// score answer - 1; even items are negatively worded and score 5 - answer.
  double get score {
    var sum = 0;
    for (final (index, answer) in answers.indexed) {
      sum += index.isEven ? answer - 1 : 5 - answer;
    }
    return sum * 2.5;
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'submittedAt': submittedAt.toIso8601String(),
    'answers': answers,
  };

  factory UsabilityResponse.fromMap(Map<dynamic, dynamic> map) =>
      UsabilityResponse(
        id: map['id'] as String,
        patientId: map['patientId'] as String,
        submittedAt: DateTime.parse(map['submittedAt'] as String),
        answers: (map['answers'] as List<dynamic>).cast<int>(),
      );
}

/// Structured participant feedback items, each rated 1 (strongly disagree)
/// to 5 (strongly agree).
enum SatisfactionItem {
  remindersHelpful,
  scheduleClear,
  instructionsClear,
  checklistEasy,
  progressMotivating,
  recordingEasy,
  privacyComfortable,
  overallSatisfied,
  wouldContinue,
}

/// Structured feedback with open comments kept for thematic analysis.
class SatisfactionResponse {
  SatisfactionResponse({
    required this.id,
    required this.patientId,
    required this.submittedAt,
    required Map<SatisfactionItem, int> ratings,
    this.likedMost = '',
    this.difficulties = '',
    this.suggestions = '',
  }) : ratings = Map.unmodifiable(ratings) {
    final complete = SatisfactionItem.values.every(
      (item) => (ratings[item] ?? 0) >= 1 && ratings[item]! <= 5,
    );
    if (!complete) {
      throw ArgumentError.value(ratings, 'ratings', 'needs every item 1-5');
    }
  }

  final String id;
  final String patientId;
  final DateTime submittedAt;
  final Map<SatisfactionItem, int> ratings;
  final String likedMost;
  final String difficulties;
  final String suggestions;

  /// Mean rating across every item, 1 to 5.
  double get meanRating =>
      ratings.values.fold(0, (sum, r) => sum + r) / ratings.length;

  Map<String, Object?> toMap() => {
    'id': id,
    'patientId': patientId,
    'submittedAt': submittedAt.toIso8601String(),
    'ratings': {for (final e in ratings.entries) e.key.name: e.value},
    'likedMost': likedMost,
    'difficulties': difficulties,
    'suggestions': suggestions,
  };

  factory SatisfactionResponse.fromMap(Map<dynamic, dynamic> map) =>
      SatisfactionResponse(
        id: map['id'] as String,
        patientId: map['patientId'] as String,
        submittedAt: DateTime.parse(map['submittedAt'] as String),
        ratings: {
          for (final MapEntry(:key, :value)
              in (map['ratings'] as Map<dynamic, dynamic>).entries)
            SatisfactionItem.values.byName(key as String): value as int,
        },
        likedMost: map['likedMost'] as String? ?? '',
        difficulties: map['difficulties'] as String? ?? '',
        suggestions: map['suggestions'] as String? ?? '',
      );
}

/// Every questionnaire a participant has submitted.
class QuestionnaireHistory {
  const QuestionnaireHistory({
    this.selfReports = const [],
    this.usability = const [],
    this.satisfaction = const [],
  });

  /// Ordered by week.
  final List<AdherenceSelfReport> selfReports;
  final List<UsabilityResponse> usability;
  final List<SatisfactionResponse> satisfaction;

  AdherenceSelfReport? reportForWeek(int week) =>
      selfReports.where((r) => r.week == week).firstOrNull;

  AdherenceSelfReport? get baseline =>
      reportForWeek(AdherenceSelfReport.baselineWeek);

  /// The most recent weekly (not baseline) report.
  AdherenceSelfReport? get latestWeekly =>
      selfReports.where((r) => !r.isBaseline).lastOrNull;
}

abstract interface class QuestionnaireRepository {
  Future<QuestionnaireHistory> forPatient(String patientId);

  /// Every participant's responses, for export and study outcomes.
  Future<List<AdherenceSelfReport>> allSelfReports();

  Future<List<UsabilityResponse>> allUsability();

  Future<List<SatisfactionResponse>> allSatisfaction();

  Future<void> saveSelfReport(AdherenceSelfReport report);

  Future<void> saveUsability(UsabilityResponse response);

  Future<void> saveSatisfaction(SatisfactionResponse response);
}
