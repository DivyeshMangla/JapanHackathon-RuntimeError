import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Device-only data: reminder times, this phone's access log and a child's
/// unsent word attempt. Everything else lives on the care service. Every box is opened with one AES-256 key
/// that lives only in the platform keystore (Android Keystore / iOS Keychain).
class LocalDatabase {
  LocalDatabase._({
    required this.reminders,
    required this.accessLog,
    required this.wordDrafts,
  });

  static const _keyName = 'hive_encryption_key_v1';

  /// Reminder times (minutes after midnight) keyed by user id.
  final Box<List<dynamic>> reminders;

  /// Append-only record of recording playback and data export.
  final Box<Map<dynamic, dynamic>> accessLog;

  /// A word attempt that failed to send, keyed by child id, so it is never
  /// lost before it reaches the therapist.
  final Box<String> wordDrafts;

  static Future<LocalDatabase> open({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) async {
    await Hive.initFlutter('melo');
    final cipher = HiveAesCipher(await _loadOrCreateKey(secureStorage));

    Future<Box<Map<dynamic, dynamic>>> records(String name) =>
        Hive.openBox<Map<dynamic, dynamic>>(name, encryptionCipher: cipher);

    return LocalDatabase._(
      reminders: await Hive.openBox<List<dynamic>>(
        'reminders',
        encryptionCipher: cipher,
      ),
      accessLog: await records('access_log'),
      wordDrafts: await Hive.openBox<String>(
        'word_drafts',
        encryptionCipher: cipher,
      ),
    );
  }

  static Future<List<int>> _loadOrCreateKey(
    FlutterSecureStorage storage,
  ) async {
    final stored = await storage.read(key: _keyName);
    if (stored != null) return base64Url.decode(stored);

    final key = Hive.generateSecureKey();
    await storage.write(key: _keyName, value: base64Url.encode(key));
    return key;
  }
}

/// Overridden in main() with the opened database.
final localDatabaseProvider = Provider<LocalDatabase>(
  (ref) => throw StateError('LocalDatabase was not opened before runApp'),
);
