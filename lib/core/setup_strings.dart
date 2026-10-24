import 'dart:convert';

import 'package:flutter/services.dart';

class SetupStrings {
  static final _locales = <String, Map<String, dynamic>>{};
  static Future<void> load() async {
    for (final locale in ['en', 'hi', 'pa']) {
      _locales[locale] =
          jsonDecode(
                await rootBundle.loadString(
                  'lib/features/setup/l10n/setup_$locale.arb',
                ),
              )
              as Map<String, dynamic>;
    }
  }

  static String text(String locale, String key) =>
      (_locales[locale]?[key] ?? _locales['en']?[key] ?? key) as String;

  /// [text] with each `{name}` placeholder replaced by its value.
  static String format(String locale, String key, Map<String, Object> values) =>
      values.entries.fold(
        text(locale, key),
        (result, entry) =>
            result.replaceAll('{${entry.key}}', entry.value.toString()),
      );
}
