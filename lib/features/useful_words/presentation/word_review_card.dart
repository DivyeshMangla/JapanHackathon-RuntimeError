import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../data/word_repository.dart';
import '../domain/useful_word.dart';
import 'word_analysis_panel.dart';
import 'word_audio_controller.dart';
import 'word_capture_panel.dart';
import 'word_page_actions.dart';
import 'word_strings.dart';

class WordReviewCard extends StatefulWidget {
  const WordReviewCard({
    super.key,
    required this.attempt,
    required this.repository,
    required this.onSaved,
    this.audio,
  });
  final WordAudioController? audio;
  final WordAttempt attempt;
  final WordRepository repository;
  final VoidCallback onSaved;
  @override
  State<WordReviewCard> createState() => _WordReviewCardState();
}

class _WordReviewCardState extends State<WordReviewCard> with WordPageActions {
  late final _audio = widget.audio ?? WordAudioController();
  late final _correction = TextEditingController(
    text: widget.attempt.analysisCorrection ?? '',
  );
  late final _feedback = TextEditingController(text: widget.attempt.feedback);
  late bool _reviewed = widget.attempt.reviewed;
  late WordTherapistOutcome _outcome = widget.attempt.therapistOutcome;
  late bool _saved =
      widget.attempt.reviewed ||
      widget.attempt.feedback.isNotEmpty ||
      widget.attempt.hasFeedbackAudio;
  @override
  void dispose() {
    _feedback.dispose();
    _correction.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await run(
      () => widget.repository.review(
        widget.attempt.id,
        _feedback.text,
        _reviewed,
        analysisCorrection: _correction.text,
        therapistOutcome: _reviewed
            ? _outcome
            : WordTherapistOutcome.notAssessed,
        audio: _audio.audio,
        preserveAudio: widget.attempt.hasFeedbackAudio && _audio.audio == null,
      ),
    );
    if (saved && mounted) {
      FocusScope.of(context).unfocus();
      await _audio.clear();
      if (!mounted) return;
      setState(() => _saved = true);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    if (_saved) {
      return InkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(attempt.word, style: Theme.of(context).textTheme.titleMedium),
            const Text(WordStrings.saved),
            if (_feedback.text.trim().isNotEmpty) Text(_feedback.text.trim()),
            SecondaryButton(
              label: 'Edit feedback',
              icon: LucideIcons.pencil,
              onPressed: () => setState(() => _saved = false),
            ),
          ],
        ),
      );
    }
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WordReviewPlayback(
            attempt: attempt,
            onPlayReference: busy || _audio.recording
                ? null
                : () => unawaited(
                    run(
                      () async => _audio.play(
                        await widget.repository.audio(
                          'attempts',
                          attempt.id,
                          reference: true,
                        ),
                      ),
                    ),
                  ),
            onPlay: busy || _audio.recording
                ? null
                : () => unawaited(
                    run(
                      () async => _audio.play(
                        await widget.repository.audio('attempts', attempt.id),
                      ),
                    ),
                  ),
            onStop: () => unawaited(_audio.stopPlayback()),
          ),
          const Divider(),
          WordAnalysisPanel(
            report: attempt.analysisReport,
            targetWord: attempt.word,
            recognizedWord: attempt.transcript,
            correction: _correction,
            enabled: !busy,
          ),
          SecondaryButton(
            label: attempt.analysisReport?.processingStatus == 'complete'
                ? WordStrings.regenerateReport
                : WordStrings.generateReport,
            icon: LucideIcons.refreshCw,
            onPressed:
                busy ||
                    _audio.recording ||
                    attempt.transcriptionStatus == 'pending'
                ? null
                : () => unawaited(
                    run(() async {
                      await widget.repository.generateReport(attempt.id);
                      widget.onSaved();
                    }),
                  ),
          ),
          const Divider(),
          TextField(
            controller: _feedback,
            enabled: !busy,
            maxLength: 2000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: WordStrings.feedbackHint,
            ),
          ),
          const Text(WordStrings.voiceFeedback),
          WordCapturePanel(audio: _audio, enabled: !busy),
          if (attempt.hasFeedbackAudio)
            SecondaryButton(
              label: WordStrings.playFeedback,
              icon: LucideIcons.volume2,
              onPressed: busy || _audio.recording
                  ? null
                  : () => unawaited(
                      run(
                        () async => _audio.play(
                          await widget.repository.audio(
                            'attempts',
                            attempt.id,
                            feedback: true,
                          ),
                        ),
                      ),
                    ),
            ),
          _TherapistOutcomePicker(
            outcome: _outcome,
            onChanged: busy
                ? null
                : (value) => setState(() {
                    _outcome = value;
                    if (value != WordTherapistOutcome.notAssessed) {
                      _reviewed = true;
                    }
                  }),
          ),
          CheckboxListTile(
            value: _reviewed,
            onChanged: busy
                ? null
                : (v) => setState(() => _reviewed = v ?? false),
            title: const Text(WordStrings.markReviewed),
          ),
          if (error != null) InfoNotice(error!),
          if (_saved) const Text(WordStrings.saved),
          PrimaryButton(
            label: WordStrings.review,
            icon: LucideIcons.check,
            onPressed: busy || _audio.recording || _audio.busy
                ? null
                : () => unawaited(_save()),
          ),
        ],
      ),
    );
  }
}

class _WordReviewPlayback extends StatelessWidget {
  const _WordReviewPlayback({
    required this.attempt,
    required this.onPlay,
    required this.onStop,
    required this.onPlayReference,
  });
  final WordAttempt attempt;
  final VoidCallback? onPlay;
  final VoidCallback onStop;
  final VoidCallback? onPlayReference;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${attempt.word} · ${DateFormat.yMMMd().add_Hm().format(attempt.date)}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (attempt.reviewed) const Text(WordStrings.reviewed),
      SecondaryButton(
        label: WordStrings.original,
        icon: LucideIcons.play,
        onPressed: onPlay,
      ),
      if (attempt.hasReferenceAudio)
        SecondaryButton(
          label: WordStrings.referenceOriginal,
          icon: LucideIcons.play,
          onPressed: onPlayReference,
        ),
      SecondaryButton(
        label: WordStrings.stopPlayback,
        icon: LucideIcons.square,
        onPressed: onStop,
      ),
    ],
  );
}

class _TherapistOutcomePicker extends StatelessWidget {
  const _TherapistOutcomePicker({
    required this.outcome,
    required this.onChanged,
  });
  final WordTherapistOutcome outcome;
  final ValueChanged<WordTherapistOutcome>? onChanged;
  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<WordTherapistOutcome>(
        initialValue: outcome,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: WordStrings.assessment,
          helperText: WordStrings.assessmentHint,
          helperMaxLines: 4,
        ),
        items: [
          for (final value in WordTherapistOutcome.values)
            DropdownMenuItem(
              value: value,
              child: Text(switch (value) {
                WordTherapistOutcome.correct => WordStrings.correct,
                WordTherapistOutcome.needsPractice => WordStrings.needsPractice,
                WordTherapistOutcome.notAssessed => WordStrings.notAssessed,
              }),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (value) {
                if (value != null) onChanged!(value);
              },
      );
}
