class PronunciationReport {
  const PronunciationReport({
    required this.targetWord,
    required this.recognizedWord,
    required this.textComparison,
    required this.processingStatus,
    required this.validation,
    required this.limitations,
    this.captureQuality,
    this.modelId,
    this.language,
    this.textSimilarity,
    this.reference,
    this.referenceTranscriptComparison,
    this.audioComparison,
    this.recognitionWarnings = const [],
    this.provider,
  });
  final String targetWord, textComparison, processingStatus, validation;
  final String? recognizedWord;
  final List<String> limitations;
  final WordCaptureQuality? captureQuality;
  final String? modelId, language;
  final String? provider;
  final WordTextComparison? textSimilarity, referenceTranscriptComparison;
  final WordReferenceComparison? reference;
  final WordAudioComparison? audioComparison;
  final List<String> recognitionWarnings;
  // Scoring is intentionally unavailable until a validated pronunciation model
  // and its eligibility/quality gates are integrated on the server.
  factory PronunciationReport.fromJson(Map<String, dynamic> json) =>
      PronunciationReport(
        modelId: json['modelId'] as String?,
        language: json['language'] as String?,
        provider: json['provider'] as String?,
        textSimilarity: json['textSimilarity'] == null
            ? null
            : WordTextComparison.fromJson(
                json['textSimilarity'] as Map<String, dynamic>,
              ),
        referenceTranscriptComparison:
            json['referenceTranscriptComparison'] == null
            ? null
            : WordTextComparison.fromJson(
                json['referenceTranscriptComparison'] as Map<String, dynamic>,
              ),
        reference: json['reference'] == null
            ? null
            : WordReferenceComparison.fromJson(
                json['reference'] as Map<String, dynamic>,
              ),
        audioComparison: json['audioComparison'] == null
            ? null
            : WordAudioComparison.fromJson(
                json['audioComparison'] as Map<String, dynamic>,
              ),
        recognitionWarnings: List.unmodifiable(
          ((json['recognitionEvidence'] as Map<String, dynamic>?)?['warnings']
                      as List? ??
                  const [])
              .cast<String>(),
        ),
        captureQuality: json['captureQuality'] == null
            ? null
            : WordCaptureQuality.fromJson(
                json['captureQuality'] as Map<String, dynamic>,
              ),
        targetWord: json['targetWord'] as String,
        recognizedWord: json['recognizedWord'] as String?,
        textComparison: json['textComparison'] as String,
        processingStatus: json['processingStatus'] as String,
        validation: json['validation'] as String,
        limitations: List.unmodifiable(
          (json['limitations'] as List).cast<String>(),
        ),
      );
}

class WordTextComparison {
  const WordTextComparison({
    required this.status,
    this.textSimilarityPercent,
    this.characterEditDistance,
    this.wordEditDistance,
  });
  final String status;
  final double? textSimilarityPercent;
  final int? characterEditDistance, wordEditDistance;
  factory WordTextComparison.fromJson(Map<String, dynamic> json) =>
      WordTextComparison(
        status: json['status'] as String,
        textSimilarityPercent: (json['textSimilarityPercent'] as num?)
            ?.toDouble(),
        characterEditDistance: json['characterEditDistance'] as int?,
        wordEditDistance: json['wordEditDistance'] as int?,
      );
}

class WordReferenceComparison {
  const WordReferenceComparison({
    required this.recognitionStatus,
    required this.needsReview,
    this.recognizedText,
  });
  final String recognitionStatus;
  final bool needsReview;
  final String? recognizedText;
  factory WordReferenceComparison.fromJson(Map<String, dynamic> json) =>
      WordReferenceComparison(
        recognitionStatus:
            json['recognitionStatus'] as String? ?? 'unavailable',
        needsReview: json['needsReview'] as bool? ?? false,
        recognizedText: json['recognizedText'] as String?,
      );
}

class WordAudioComparison {
  const WordAudioComparison({
    required this.status,
    this.referenceDurationSeconds,
    this.attemptDurationSeconds,
    this.durationRatio,
  });
  final String status;
  final double? referenceDurationSeconds, attemptDurationSeconds, durationRatio;
  factory WordAudioComparison.fromJson(Map<String, dynamic> json) =>
      WordAudioComparison(
        status: json['status'] as String,
        referenceDurationSeconds: (json['referenceDurationSeconds'] as num?)
            ?.toDouble(),
        attemptDurationSeconds: (json['attemptDurationSeconds'] as num?)
            ?.toDouble(),
        durationRatio: (json['durationRatio'] as num?)?.toDouble(),
      );
}

class WordCaptureQuality {
  const WordCaptureQuality({
    required this.status,
    required this.reasons,
    this.durationSeconds,
    this.sampleRate,
    this.clippingFraction,
    this.rmsDbfs,
  });
  final String status;
  final List<String> reasons;
  final double? durationSeconds, clippingFraction, rmsDbfs;
  final int? sampleRate;
  factory WordCaptureQuality.fromJson(Map<String, dynamic> json) =>
      WordCaptureQuality(
        status: json['status'] as String,
        reasons: List.unmodifiable((json['reasons'] as List).cast<String>()),
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
        sampleRate: json['sampleRate'] as int?,
        clippingFraction: (json['clippingFraction'] as num?)?.toDouble(),
        rmsDbfs: (json['rmsDbfs'] as num?)?.toDouble(),
      );
}
