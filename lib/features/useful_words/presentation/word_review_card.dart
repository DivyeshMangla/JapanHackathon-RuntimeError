import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../data/word_repository.dart';
import '../domain/useful_word.dart';
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
  });
  final WordAttempt attempt;
  final WordRepository repository;
  final VoidCallback onSaved;
  @override
  State<WordReviewCard> createState() => _WordReviewCardState();
}

class _WordReviewCardState extends State<WordReviewCard> with WordPageActions {
  final _audio = WordAudioController();
  late final _feedback = TextEditingController(text: widget.attempt.feedback);
  late bool _reviewed = widget.attempt.reviewed;
  bool _saved = false;
  @override
  void dispose() {
    _feedback.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await run(
      () => widget.repository.review(
        widget.attempt.id,
        _feedback.text,
        _reviewed,
        audio: _audio.audio,
        preserveAudio: widget.attempt.hasFeedbackAudio && _audio.audio == null,
      ),
    );
    if (saved && mounted) {
      setState(() => _saved = true);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WordReviewPlayback(
            attempt: attempt,
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
          TextField(
            controller: _feedback,
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
  });
  final WordAttempt attempt;
  final VoidCallback? onPlay;
  final VoidCallback onStop;
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
      SecondaryButton(
        label: WordStrings.stopPlayback,
        icon: LucideIcons.square,
        onPressed: onStop,
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(WordStrings.ai),
      Text(
        attempt.transcriptionStatus == 'suggested'
            ? attempt.transcript ?? WordStrings.noTranscript
            : attempt.transcriptionStatus == 'pending'
            ? WordStrings.transcribing
            : WordStrings.noTranscript,
      ),
    ],
  );
}
