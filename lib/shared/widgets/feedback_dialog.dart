import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/l10n.dart';
import 'labeled_text_field.dart';

/// The care service keeps at most this many characters of feedback.
const _maxFeedbackLength = 2000;

/// Asks the therapist for a note. Returns the note, or null when cancelled.
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key, this.initial = ''});

  final String initial;

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  late final _note = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = _note.text.trim();
    return AlertDialog(
      title: Text(l10n.feedbackTitle),
      content: LabeledTextField(
        label: l10n.feedbackLabel,
        controller: _note,
        maxLines: 4,
        inputFormatters: [LengthLimitingTextInputFormatter(_maxFeedbackLength)],
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: note.isEmpty ? null : () => Navigator.pop(context, note),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
