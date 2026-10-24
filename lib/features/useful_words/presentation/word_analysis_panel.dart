import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        WordStrings.reportTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const InfoNotice(WordStrings.unable),
      Text('${WordStrings.target}: ${report?.targetWord ?? targetWord}'),
      Text(
        '${WordStrings.recognized}: ${report?.recognizedWord ?? recognizedWord ?? WordStrings.unavailable}',
      ),
      if (report?.textComparison == 'same_text')
        const Text(WordStrings.sameText),
      if (report?.textComparison == 'different_text')
        const Text(WordStrings.differentText),
      const Text(WordStrings.accuracyUnavailable),
      const Text(WordStrings.soundsUnavailable),
      const Text(WordStrings.confidenceUnavailable),
      if (report != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(report!.validation),
        for (final limitation in report!.limitations)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(limitation),
          ),
      ],
      const SizedBox(height: AppSpacing.md),
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
