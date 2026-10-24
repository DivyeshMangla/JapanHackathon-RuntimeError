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
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await run(() async {
      final practice = await widget.repository.load();
      if (mounted) setState(() => _practice = practice);
    });
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
        if (practice != null && !practice.enrolled)
          _EnrollmentForm(
            repository: widget.repository,
            onSaved: () => unawaited(_load()),
          ),
        if (practice?.enrolled == true) ...[
          WordAssignmentForm(
            repository: widget.repository,
            onSaved: () => unawaited(_load()),
          ),
          if (practice!.mockTranscription)
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
                  '${attempt.id}-${attempt.reviewed}-${attempt.feedback}-${attempt.hasFeedbackAudio}',
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

class _EnrollmentForm extends StatefulWidget {
  const _EnrollmentForm({required this.repository, required this.onSaved});
  final WordRepository repository;
  final VoidCallback onSaved;
  @override
  State<_EnrollmentForm> createState() => _EnrollmentFormState();
}

class _EnrollmentFormState extends State<_EnrollmentForm> with WordPageActions {
  final _birth = TextEditingController();
  bool _eligible = false;
  @override
  void dispose() {
    _birth.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await run(() => widget.repository.enroll(_birth.text.trim())) &&
        mounted) {
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        controller: _birth,
        decoration: const InputDecoration(labelText: WordStrings.birth),
        onChanged: (_) => setState(() {}),
      ),
      CheckboxListTile(
        value: _eligible,
        onChanged: busy ? null : (v) => setState(() => _eligible = v ?? false),
        title: const Text(WordStrings.eligibility),
      ),
      if (error != null) InfoNotice(error!),
      PrimaryButton(
        label: WordStrings.enroll,
        icon: LucideIcons.check,
        onPressed: busy || !_eligible || _birth.text.isEmpty
            ? null
            : () => unawaited(_save()),
      ),
    ],
  );
}
