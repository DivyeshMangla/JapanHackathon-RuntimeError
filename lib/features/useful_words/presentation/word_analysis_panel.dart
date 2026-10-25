import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/accuracy_chart.dart';
import '../../../shared/widgets/action_page.dart';
import '../domain/pronunciation_report.dart';
import 'word_strings.dart';

/// The automated snapshot stays separate from editable clinician corrections.
class WordAnalysisPanel extends StatelessWidget {
  const WordAnalysisPanel({
    super.key,
    required this.report,
    required this.targetWord,
    required this.recognizedWord,
    required this.correction,
    required this.enabled,
  });
  final PronunciationReport? report;
  final String targetWord;
  final String? recognizedWord;
  final TextEditingController correction;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final status = report?.processingStatus;
    double? share(WordTextComparison? comparison) =>
        comparison?.textSimilarityPercent == null
        ? null
        : comparison!.textSimilarityPercent! / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status == 'complete')
          AccuracyChart(
            title: WordStrings.matchTitle,
            notAssessable: WordStrings.notAssessable,
            measures: [
              AccuracyMeasure(
                WordStrings.matchWord,
                share(report!.textSimilarity),
              ),
              if (report!.reference != null)
                AccuracyMeasure(
                  WordStrings.matchExample,
                  share(report!.referenceTranscriptComparison),
                ),
            ],
          )
        else
          InfoNotice(WordStrings.reportStatus(status)),
        Text(
          WordStrings.matchCaption,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        _ReportDetails(
          report: report,
          targetWord: targetWord,
          recognizedWord: recognizedWord,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: correction,
          enabled: enabled,
          maxLength: 4000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: WordStrings.correction,
            helperText: WordStrings.correctionHint,
            helperMaxLines: 4,
          ),
        ),
      ],
    );
  }
}

/// The automated wording and capture measurements stay one tap away for the
/// therapist to verify.
class _ReportDetails extends StatelessWidget {
  const _ReportDetails({
    required this.report,
    required this.targetWord,
    required this.recognizedWord,
  });
  final PronunciationReport? report;
  final String targetWord;
  final String? recognizedWord;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text(WordStrings.details),
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        WordStrings.reportTitle,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      if (report?.processingStatus == 'complete')
        InfoNotice(WordStrings.reportStatus(report!.processingStatus)),
      Text('${WordStrings.target}: ${report?.targetWord ?? targetWord}'),
      Text(
        '${WordStrings.recognized}: ${report?.recognizedWord ?? recognizedWord ?? WordStrings.unavailable}',
      ),
      if (report?.textComparison == 'same_text')
        const Text(WordStrings.sameText),
      if (report?.textComparison == 'different_text')
        const Text(WordStrings.differentText),
      if (report?.textSimilarity != null)
        _TextSimilarity(
          comparison: report!.textSimilarity!,
          label: WordStrings.textSimilarity,
        ),
      const Text(WordStrings.accuracyUnavailable),
      const Text(WordStrings.soundsUnavailable),
      const Text(WordStrings.confidenceUnavailable),
      if (report != null) ...[
        const SizedBox(height: AppSpacing.sm),
        _CaptureQuality(report: report!),
        _ReferenceComparison(report: report!),
        for (final warning in report!.recognitionWarnings) InfoNotice(warning),
        if (report!.modelId != null)
          Text(
            '${WordStrings.model}: ${report!.modelId} (${report!.language ?? WordStrings.unavailable})',
          ),
        Text(report!.validation),
        for (final limitation in report!.limitations)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(limitation),
          ),
      ],
    ],
  );
}

class _TextSimilarity extends StatelessWidget {
  const _TextSimilarity({required this.comparison, required this.label});
  final WordTextComparison comparison;
  final String label;
  @override
  Widget build(BuildContext context) {
    if (comparison.textSimilarityPercent == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: ${comparison.textSimilarityPercent!.toStringAsFixed(1)}'),
        Text(
          '${WordStrings.characterEdits}: ${comparison.characterEditDistance} · ${WordStrings.wordEdits}: ${comparison.wordEditDistance}',
        ),
        const Text(WordStrings.textSimilarityHint),
      ],
    );
  }
}

class _ReferenceComparison extends StatelessWidget {
  const _ReferenceComparison({required this.report});
  final PronunciationReport report;
  @override
  Widget build(BuildContext context) {
    final reference = report.reference, timing = report.audioComparison;
    if (reference == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${WordStrings.referenceRecognized}: ${reference.recognizedText ?? WordStrings.unavailable}',
        ),
        if (reference.needsReview)
          const InfoNotice(WordStrings.referenceReview),
        if (reference.recognizedText == null)
          const Text(WordStrings.referenceUnavailable),
        if (report.referenceTranscriptComparison != null)
          _TextSimilarity(
            comparison: report.referenceTranscriptComparison!,
            label: WordStrings.referenceSimilarity,
          ),
        if (timing?.referenceDurationSeconds != null)
          Text(
            '${WordStrings.referenceDuration}: ${timing!.referenceDurationSeconds!.toStringAsFixed(2)}',
          ),
        if (timing?.durationRatio != null) ...[
          Text(
            '${WordStrings.durationRatio}: ${timing!.durationRatio!.toStringAsFixed(2)}',
          ),
          const Text(WordStrings.timingHint),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _CaptureQuality extends StatelessWidget {
  const _CaptureQuality({required this.report});
  final PronunciationReport report;
  @override
  Widget build(BuildContext context) {
    final quality = report.captureQuality;
    if (quality == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          WordStrings.captureTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(switch (quality.status) {
          'checked' => WordStrings.captureChecked,
          'retake' => WordStrings.captureBlocked,
          _ => WordStrings.captureUnavailable,
        }),
        for (final reason in quality.reasons) Text(reason),
        if (quality.durationSeconds != null)
          Text(
            '${WordStrings.duration}: ${quality.durationSeconds!.toStringAsFixed(2)}',
          ),
        if (quality.sampleRate != null)
          Text('${WordStrings.sampleRate}: ${quality.sampleRate}'),
        if (quality.rmsDbfs != null)
          Text('${WordStrings.level}: ${quality.rmsDbfs!.toStringAsFixed(1)}'),
        if (quality.clippingFraction != null)
          Text(
            '${WordStrings.clipping}: ${(quality.clippingFraction! * 100).toStringAsFixed(2)}',
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
