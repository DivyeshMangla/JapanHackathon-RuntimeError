import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/l10n.dart';
import 'labeled_text_field.dart';

/// Optional positive decimal input with inline validation. Set [wholeNumber]
/// to require an integer of at least 1 instead.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.wholeNumber = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool wholeNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LabeledTextField(
      label: label,
      controller: controller,
      hint: hint,
      keyboardType: TextInputType.numberWithOptions(decimal: !wholeNumber),
      inputFormatters: [
        wholeNumber
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      validator: (value) {
        final text = (value ?? '').trim();
        if (wholeNumber) {
          final number = int.tryParse(text);
          return number == null || number < 1 ? l10n.wholeNumberRequired : null;
        }
        if (text.isEmpty) return null;
        final number = double.tryParse(text);
        return number == null || number <= 0 ? l10n.invalidNumber : null;
      },
    );
  }
}
