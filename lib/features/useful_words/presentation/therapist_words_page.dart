import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../data/word_repository.dart';
import '../domain/useful_word.dart';
import 'word_assignment_form.dart';
import 'word_page_actions.dart';
import 'word_review_card.dart';
import 'word_strings.dart';

class TherapistWordsPage extends StatefulWidget {
  const TherapistWordsPage({
    super.key,
    required this.repository,
    required this.childName,
  });
  final WordRepository repository;
  final String childName;
  @override
  State<TherapistWordsPage> createState() => _TherapistWordsPageState();
}

class _TherapistWordsPageState extends State<TherapistWordsPage>
    with WordPageActions {
  WordPractice? _practice;
  Timer? _reportRefresh;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    _reportRefresh?.cancel();
    await run(() async {
      final practice = await widget.repository.load();
      if (mounted) setState(() => _practice = practice);
    });
    if (mounted &&
        error == null &&
        (_practice?.attempts.any((a) => a.transcriptionStatus == 'pending') ??
            false)) {
      _reportRefresh = Timer(
        const Duration(seconds: 3),
        () => unawaited(_load()),
      );
    }
  }

  @override
  void dispose() {
    _reportRefresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final practice = _practice;
    final groups = <String, List<WordAttempt>>{};
    for (final attempt in practice?.attempts ?? <WordAttempt>[]) {
      final group =
          '${attempt.word} · ${DateFormat.yMMMd().format(attempt.date)}';
      groups.putIfAbsent(group, () => []).add(attempt);
    }
    return ActionPage(
      title: '${widget.childName} · ${WordStrings.therapist}',
      onBack: () => Navigator.pop(context),
      backLabel: WordStrings.back,
      error: error,
      actions: [
        SecondaryButton(
          label: WordStrings.retry,
          icon: LucideIcons.refreshCw,
          onPressed: busy ? null : () => unawaited(_load()),
        ),
      ],
      children: [
        if (busy) const LinearProgressIndicator(),
        const InfoNotice(WordStrings.scope),
        if (practice != null) ...[
          WordAssignmentForm(
            repository: widget.repository,
            onSaved: () => unawaited(_load()),
          ),
          if (practice.mockTranscription)
            const PlaceholderNotice(WordStrings.mock),
          for (final word in practice.words)
            Text(word.word, style: Theme.of(context).textTheme.titleMedium),
          if (practice.attempts.isEmpty)
            const InfoNotice(WordStrings.noAttempts),
          for (final group in groups.entries) ...[
            Text(group.key, style: Theme.of(context).textTheme.titleLarge),
            for (final attempt in group.value)
              WordReviewCard(
                key: ValueKey(
                  '${attempt.id}-${attempt.reviewed}-${attempt.feedback}-${attempt.hasFeedbackAudio}-${attempt.analysisCorrection}-${attempt.therapistOutcome}-${attempt.reviewedAt}',
                ),
                attempt: attempt,
                repository: widget.repository,
                onSaved: () => unawaited(_load()),
              ),
          ],
        ],
      ],
    );
  }
}
