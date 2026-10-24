import 'pronunciation_report.dart';

class UsefulWord {
  const UsefulWord({
    required this.id,
    required this.word,
    required this.picture,
  });
  final String id;
  final String word;
  final String picture;
  factory UsefulWord.fromJson(Map<String, dynamic> json) => UsefulWord(
    id: json['id'] as String,
    word: json['word'] as String,
    picture: json['picture'] as String,
  );
}

enum WordTherapistOutcome {
  correct,
  needsPractice,
  notAssessed;

  String get wireValue => switch (this) {
    correct => 'correct',
    needsPractice => 'needs_practice',
    notAssessed => 'not_assessed',
  };
  static WordTherapistOutcome fromWire(String? value) => switch (value) {
    'correct' => correct,
    'needs_practice' => needsPractice,
    _ => notAssessed,
  };
}

class WordAttempt {
  const WordAttempt({
    required this.id,
    required this.word,
    required this.date,
    required this.transcriptionStatus,
    required this.feedback,
    required this.hasFeedbackAudio,
    required this.reviewed,
    this.transcript,
    this.analysisReport,
    this.analysisCorrection,
    this.therapistOutcome = WordTherapistOutcome.notAssessed,
    this.reviewedAt,
    this.reviewedBy,
    this.hasReferenceAudio = false,
  });
  final String id, word, transcriptionStatus, feedback;
  final DateTime date;
  final PronunciationReport? analysisReport;
  final String? analysisCorrection;
  final String? transcript;
  final bool hasFeedbackAudio, reviewed, hasReferenceAudio;
  final WordTherapistOutcome therapistOutcome;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  factory WordAttempt.fromJson(Map<String, dynamic> json) => WordAttempt(
    id: json['id'] as String,
    word: json['word'] as String,
    date: DateTime.parse(json['date'] as String).toLocal(),
    transcriptionStatus: json['transcriptionStatus'] as String,
    transcript: json['transcript'] as String?,
    feedback: json['feedback'] as String,
    hasFeedbackAudio: json['hasFeedbackAudio'] as bool,
    hasReferenceAudio: json['hasReferenceAudio'] as bool? ?? false,
    reviewed: json['reviewed'] as bool,
    therapistOutcome: WordTherapistOutcome.fromWire(
      json['therapistOutcome'] as String?,
    ),
    reviewedAt: json['reviewedAt'] == null
        ? null
        : DateTime.parse(json['reviewedAt'] as String).toLocal(),
    reviewedBy: json['reviewedBy'] as String?,
    analysisReport: json['analysisReport'] == null
        ? null
        : PronunciationReport.fromJson(
            json['analysisReport'] as Map<String, dynamic>,
          ),
    analysisCorrection: json['analysisCorrection'] == null
        ? null
        : (json['analysisCorrection'] as Map<String, dynamic>)['text']
              as String?,
  );
}

class WordPractice {
  const WordPractice({
    required this.enrolled,
    required this.consented,
    required this.mockTranscription,
    required this.words,
    required this.attempts,
  });
  final bool enrolled, consented, mockTranscription;
  final List<UsefulWord> words;
  final List<WordAttempt> attempts;
  factory WordPractice.fromJson(Map<String, dynamic> json) => WordPractice(
    enrolled: json['enrollment'] as bool,
    consented: json['consent'] as bool,
    mockTranscription: json['mockTranscription'] as bool,
    words: List.unmodifiable(
      (json['words'] as List).map(
        (w) => UsefulWord.fromJson(w as Map<String, dynamic>),
      ),
    ),
    attempts: List.unmodifiable(
      (json['attempts'] as List).map(
        (a) => WordAttempt.fromJson(a as Map<String, dynamic>),
      ),
    ),
  );
}

class PendingWordAttempt {
  const PendingWordAttempt({
    required this.id,
    required this.wordId,
    required this.audio,
  });
  final String id, wordId, audio;
  Map<String, dynamic> toJson() => {'id': id, 'wordId': wordId, 'audio': audio};
  factory PendingWordAttempt.fromJson(Map<String, dynamic> json) =>
      PendingWordAttempt(
        id: json['id'] as String,
        wordId: json['wordId'] as String,
        audio: json['audio'] as String,
      );
}
