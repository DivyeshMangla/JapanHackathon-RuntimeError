import '../../../core/utils/l10n.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Form validators for account fields, matching the care service's rules.
String? requiredText(AppLocalizations l10n, String? value) =>
    (value ?? '').trim().isEmpty ? l10n.fieldRequired : null;

String? requiredName(AppLocalizations l10n, String? value) =>
    (value ?? '').trim().isEmpty ? l10n.nameRequired : null;

String? validEmail(AppLocalizations l10n, String? value) =>
    _emailPattern.hasMatch((value ?? '').trim()) ? null : l10n.emailInvalid;

String? validPassword(AppLocalizations l10n, String? value) {
  final password = value ?? '';
  if (password.length < 10) return l10n.passwordTooShort;
  if (password.length > 128) return l10n.passwordTooLong;
  if (password != password.trim()) return l10n.passwordSpaces;
  return null;
}
