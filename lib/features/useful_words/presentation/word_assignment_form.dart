import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../data/word_media_picker.dart';
import '../data/word_repository.dart';
import 'word_audio_controller.dart';
import 'word_capture_panel.dart';
import 'word_page_actions.dart';
import 'word_strings.dart';

class WordAssignmentForm extends StatefulWidget {
  const WordAssignmentForm({
    super.key,
    required this.repository,
    required this.onSaved,
  });
  final WordRepository repository;
  final VoidCallback onSaved;
  @override
  State<WordAssignmentForm> createState() => _WordAssignmentFormState();
}

class _WordAssignmentFormState extends State<WordAssignmentForm>
    with WordPageActions {
  final _word = TextEditingController();
  final _audio = WordAudioController();
  Uint8List? _example;
  @override
  void initState() {
    super.initState();
    _audio.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {
        if (_audio.recording) _example = null;
      });
    }
  }

  @override
  void dispose() {
    _word.dispose();
    _audio.removeListener(_changed);
    _audio.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    await run(() async {
      final media = await WordMediaPicker().choose(picture: false);
      if (media == null || !mounted) return;
      await _audio.clear();
      if (mounted) setState(() => _example = media.bytes);
    });
  }

  Future<void> _save() async {
    if (await run(
          () => widget.repository.assign(
            _word.text.trim(),
            _example ?? _audio.audio!,
          ),
        ) &&
        mounted) {
      _word.clear();
      await _audio.clear();
      if (mounted) {
        setState(() {
          _example = null;
        });
        widget.onSaved();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(WordStrings.assign, style: Theme.of(context).textTheme.titleLarge),
      const InfoNotice(WordStrings.assignHint),
      TextField(
        controller: _word,
        maxLength: 80,
        decoration: const InputDecoration(labelText: WordStrings.word),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(WordStrings.example, style: Theme.of(context).textTheme.titleMedium),
      const InfoNotice(WordStrings.exampleAnalysisNotice),
      WordCapturePanel(audio: _audio, enabled: !busy),
      SecondaryButton(
        label: WordStrings.chooseExample,
        icon: LucideIcons.fileAudio,
        onPressed: busy || _audio.recording ? null : () => unawaited(_pick()),
      ),
      if (_example != null) ...[
        const Text(WordStrings.selected),
        SecondaryButton(
          label: WordStrings.listen,
          icon: LucideIcons.play,
          onPressed: () => unawaited(run(() => _audio.play(_example!))),
        ),
      ],
      if (error != null) InfoNotice(error!),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        label: WordStrings.assign,
        icon: LucideIcons.plus,
        onPressed:
            busy ||
                _audio.busy ||
                _audio.recording ||
                _word.text.trim().isEmpty ||
                (_example == null && _audio.audio == null)
            ? null
            : () => unawaited(_save()),
      ),
    ],
  );
}
