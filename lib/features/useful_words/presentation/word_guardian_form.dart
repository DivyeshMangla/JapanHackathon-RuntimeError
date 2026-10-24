import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../data/word_repository.dart';
import 'word_page_actions.dart';
import 'word_strings.dart';

class WordGuardianForm extends StatefulWidget {
  const WordGuardianForm({
    super.key,
    required this.repository,
    required this.version,
    required this.onSaved,
  });
  final WordRepository repository;
  final String version;
  final VoidCallback onSaved;
  @override
  State<WordGuardianForm> createState() => _WordGuardianFormState();
}

class _WordGuardianFormState extends State<WordGuardianForm>
    with WordPageActions {
  final _name = TextEditingController(),
      _relationship = TextEditingController();
  bool _agree = false;
  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        WordStrings.guardianTitle,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const PlaceholderNotice(WordStrings.guardianNotice),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: WordStrings.guardianName),
        onChanged: (_) => setState(() {}),
      ),
      TextField(
        controller: _relationship,
        decoration: const InputDecoration(labelText: WordStrings.relationship),
        onChanged: (_) => setState(() {}),
      ),
      CheckboxListTile(
        value: _agree,
        onChanged: busy ? null : (v) => setState(() => _agree = v ?? false),
        title: const Text(WordStrings.guardianAgree),
      ),
      if (error != null) InfoNotice(error!),
      PrimaryButton(
        label: WordStrings.consent,
        icon: LucideIcons.check,
        onPressed:
            busy ||
                !_agree ||
                _name.text.trim().isEmpty ||
                _relationship.text.trim().isEmpty
            ? null
            : () => unawaited(_save()),
      ),
    ],
  );
  Future<void> _save() async {
    if (await run(
          () => widget.repository.consent(
            widget.version,
            _name.text.trim(),
            _relationship.text.trim(),
          ),
        ) &&
        mounted) {
      widget.onSaved();
    }
  }
}
