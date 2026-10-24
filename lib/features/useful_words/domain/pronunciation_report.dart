class PronunciationReport {
  const PronunciationReport({
    required this.targetWord,
    required this.recognizedWord,
    required this.textComparison,
    required this.processingStatus,
    required this.validation,
    required this.limitations,
  });
  final String targetWord, textComparison, processingStatus, validation;
  final String? recognizedWord;
  final List<String> limitations;
  // Scoring is intentionally unavailable until a validated pronunciation model
  // and its eligibility/quality gates are integrated on the server.
  factory PronunciationReport.fromJson(Map<String, dynamic> json) =>
      PronunciationReport(
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
