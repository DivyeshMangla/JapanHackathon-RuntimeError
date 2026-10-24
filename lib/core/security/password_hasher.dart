import 'dart:convert';
import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';

/// bcrypt hashing run on a background isolate so the UI never stalls.
class PasswordHasher {
  const PasswordHasher({this.logRounds = defaultLogRounds});

  /// Cost 10 in release and profile builds. Debug builds run Dart
  /// unoptimized, where cost 10 takes over ten seconds per hash on an
  /// emulator, so they use cost 6. The cost is stored in each hash, so
  /// verification works whichever build created it.
  static const defaultLogRounds = kDebugMode ? 6 : 10;

  final int logRounds;

  /// bcrypt ignores input past 72 bytes, so longer passwords are rejected.
  static const maxBytes = 72;

  static bool isWithinLimit(String password) =>
      utf8.encode(password).length <= maxBytes;

  Future<String> hash(String password) {
    final rounds = logRounds;
    return Isolate.run(
      () => BCrypt.hashpw(password, BCrypt.gensalt(logRounds: rounds)),
    );
  }

  Future<bool> verify(String password, String hash) {
    if (!isWithinLimit(password)) return Future.value(false);
    return Isolate.run(() => BCrypt.checkpw(password, hash));
  }
}
