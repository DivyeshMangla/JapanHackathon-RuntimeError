import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../patient/presentation/child_activity_picture.dart';
import '../../patient/presentation/child_practice_intro.dart';
import '../data/word_repository.dart';
import '../domain/useful_word.dart';
import 'word_audio_controller.dart';
import 'word_capture_panel.dart';
import 'word_page_actions.dart';
import 'word_strings.dart';

enum WordDelivery { ready, uploading, delivered, failed }

class ChildWordPage extends StatefulWidget {
  const ChildWordPage({super.key, required this.repository, this.audio});
  final WordRepository repository;
  final WordAudioController? audio;
  @override
  State<ChildWordPage> createState() => _ChildWordPageState();
}

class _ChildWordPageState extends State<ChildWordPage> with WordPageActions {
  late final _audio = widget.audio ?? WordAudioController();
  WordPractice? _practice;
  int _index = 0;
  WordDelivery _delivery = WordDelivery.ready;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _audio.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _audio.removeListener(_changed);
    _audio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await run(() async {
      final practice = await widget.repository.load();
      final pending = widget.repository.pending;
      if (!mounted) return;
      setState(() {
        _practice = practice;
        if (pending != null) {
          final position = practice.words.indexWhere(
            (w) => w.id == pending.wordId,
          );
          _index = position < 0 ? 0 : position;
          _audio.audio = base64Decode(pending.audio);
          _delivery = WordDelivery.failed;
        }
      });
    });
  }

  Future<void> _send(UsefulWord word) async {
    setState(() => _delivery = WordDelivery.uploading);
    final sent = await run(() async {
      await _audio.stopPlayback();
      await widget.repository.queue(word.id, _audio.audio!);
      await widget.repository.deliver();
    });
    if (mounted) {
      setState(
        () => _delivery = sent ? WordDelivery.delivered : WordDelivery.failed,
      );
    }
  }

  Future<void> _next() async {
    await _audio.clear();
    if (mounted) {
      setState(() {
        _index++;
        _delivery = WordDelivery.ready;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final practice = _practice;
    final word = practice != null && _index < practice.words.length
        ? practice.words[_index]
        : null;
    final canPractice =
        practice?.enrolled == true && practice?.consented == true;
    return PopScope(
      canPop: !busy && !_audio.recording,
      child: ActionPage(
        backgroundColor: AppColors.paper,
        title: WordStrings.title,
        onBack: busy || _audio.recording ? null : () => Navigator.pop(context),
        backLabel: WordStrings.back,
        error: error,
        actions: [
          if (practice == null)
            SecondaryButton(
              label: WordStrings.retry,
              icon: LucideIcons.refreshCw,
              onPressed: busy ? null : () => unawaited(_load()),
            ),
          if (canPractice && word != null)
            _WordDeliveryPanel(
              delivery: _delivery,
              onSend:
                  busy ||
                      _audio.busy ||
                      _audio.recording ||
                      _audio.audio == null ||
                      _delivery == WordDelivery.delivered
                  ? null
                  : () => unawaited(_send(word)),
              onDiscard: busy ? null : () => unawaited(_discard()),
              onNext: busy || _audio.busy
                  ? null
                  : () => unawaited(
                      _delivery == WordDelivery.failed ? _exit() : _next(),
                    ),
            ),
        ],
        children: [
          const ChildPracticeIntro(
            activity: ChildActivity.words,
            message: WordStrings.guidance,
            color: AppColors.childMint,
          ),
          if (practice == null && busy) const LinearProgressIndicator(),
          if (practice != null && !practice.enrolled)
            const InfoNotice(WordStrings.waiting),
          if (practice?.enrolled == true && !practice!.consented)
            const InfoNotice(WordStrings.askParent),
          if (canPractice && word != null)
            _WordPracticePanel(
              word: word,
              audio: _audio,
              canRecord: !busy && _delivery == WordDelivery.ready,
              onListen: busy || _audio.recording
                  ? null
                  : () => unawaited(
                      run(
                        () async => _audio.play(
                          await widget.repository.audio('words', word.id),
                        ),
                      ),
                    ),
            ),
          if (canPractice && word == null)
            InfoNotice(
              practice!.words.isEmpty ? WordStrings.empty : WordStrings.done,
            ),
          if (canPractice)
            _ChildFeedbackList(
              attempts: practice!.attempts,
              onPlay: busy || _audio.recording
                  ? null
                  : (id) => unawaited(
                      run(
                        () async => _audio.play(
                          await widget.repository.audio(
                            'attempts',
                            id,
                            feedback: true,
                          ),
                        ),
                      ),
                    ),
            ),
          const InfoNotice(WordStrings.scope),
        ],
      ),
    );
  }

  Future<void> _discard() async {
    if (await run(() async {
          await widget.repository.discard();
          await _audio.clear();
        }) &&
        mounted) {
      setState(() => _delivery = WordDelivery.ready);
    }
  }

  Future<void> _exit() async {
    await _audio.clear();
    if (mounted) Navigator.pop(context);
  }
}

class _WordPicture extends StatelessWidget {
  const _WordPicture({required this.word});
  final UsefulWord word;
  @override
  Widget build(BuildContext context) => InkCard(
    child: Column(
      children: [
        Image.memory(
          base64Decode(word.picture.split(',').last),
          height: AppSizes.signaturePad,
          semanticLabel: word.word,
          errorBuilder: (_, error, stack) => const Icon(LucideIcons.image),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(word.word, style: Theme.of(context).textTheme.headlineLarge),
      ],
    ),
  );
}

class _ChildFeedback extends StatelessWidget {
  const _ChildFeedback({required this.attempt, required this.onPlay});
  final WordAttempt attempt;
  final VoidCallback? onPlay;
  @override
  Widget build(BuildContext context) => InkCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${WordStrings.feedback}: ${attempt.word}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (attempt.feedback.isNotEmpty) Text(attempt.feedback),
        if (attempt.hasFeedbackAudio)
          SecondaryButton(
            label: WordStrings.playFeedback,
            icon: LucideIcons.volume2,
            onPressed: onPlay,
          ),
      ],
    ),
  );
}

class _WordDeliveryPanel extends StatelessWidget {
  const _WordDeliveryPanel({
    required this.delivery,
    required this.onSend,
    required this.onNext,
    required this.onDiscard,
  });
  final WordDelivery delivery;
  final VoidCallback? onSend, onNext, onDiscard;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (delivery != WordDelivery.ready)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Semantics(
            liveRegion: true,
            child: InfoNotice(switch (delivery) {
              WordDelivery.uploading => WordStrings.uploading,
              WordDelivery.delivered => WordStrings.delivered,
              _ => WordStrings.failed,
            }),
          ),
        ),
      PrimaryButton(
        label: delivery == WordDelivery.uploading
            ? WordStrings.uploading
            : delivery == WordDelivery.failed
            ? WordStrings.retry
            : WordStrings.send,
        icon: LucideIcons.send,
        onPressed: onSend,
      ),
      if (delivery == WordDelivery.failed) ...[
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: WordStrings.delete,
          icon: LucideIcons.trash2,
          onPressed: onDiscard,
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      SecondaryButton(
        label: delivery == WordDelivery.delivered
            ? WordStrings.next
            : WordStrings.skip,
        icon: LucideIcons.arrowRight,
        onPressed: onNext,
      ),
    ],
  );
}

class _WordPracticePanel extends StatelessWidget {
  const _WordPracticePanel({
    required this.word,
    required this.audio,
    required this.canRecord,
    required this.onListen,
  });
  final UsefulWord word;
  final WordAudioController audio;
  final bool canRecord;
  final VoidCallback? onListen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _WordPicture(word: word),
      const SizedBox(height: AppSpacing.md),
      SecondaryButton(
        label: WordStrings.listen,
        icon: LucideIcons.volume2,
        onPressed: onListen,
      ),
      const SizedBox(height: AppSpacing.md),
      WordCapturePanel(audio: audio, enabled: canRecord),
    ],
  );
}

class _ChildFeedbackList extends StatelessWidget {
  const _ChildFeedbackList({required this.attempts, required this.onPlay});
  final List<WordAttempt> attempts;
  final void Function(String)? onPlay;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final attempt in attempts.where(
        (a) => a.feedback.isNotEmpty || a.hasFeedbackAudio,
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ChildFeedback(
            attempt: attempt,
            onPlay: onPlay == null ? null : () => onPlay!(attempt.id),
          ),
        ),
    ],
  );
}
