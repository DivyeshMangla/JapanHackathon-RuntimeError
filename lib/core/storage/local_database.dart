import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Opens every Hive box with one AES-256 key that lives only in the
/// platform keystore (Android Keystore / iOS Keychain).
class LocalDatabase {
  LocalDatabase._({
    required this.users,
    required this.credentials,
    required this.meta,
    required this.exercises,
    required this.schedules,
    required this.completions,
    required this.recordings,
    required this.reminders,
    required this.accessLog,
    required this.participants,
    required this.questionnaires,
    required this.monitoring,
    required this.usageLog,
    required this.voiceDiary,
  });

  static const _keyName = 'hive_encryption_key_v1';

  /// User records keyed by user id.
  final Box<Map<dynamic, dynamic>> users;

  /// bcrypt hashes keyed by user id, kept apart from profile data.
  final Box<String> credentials;

  /// Small app-level values such as the active session and seed version.
  final Box<Object> meta;

  final Box<Map<dynamic, dynamic>> exercises;
  final Box<Map<dynamic, dynamic>> schedules;
  final Box<Map<dynamic, dynamic>> completions;

  /// Recording metadata only; audio files live in app-private storage.
  final Box<Map<dynamic, dynamic>> recordings;

  /// Reminder times (minutes after midnight) keyed by user id.
  final Box<List<dynamic>> reminders;

  /// Append-only record of recording playback and data export.
  final Box<Map<dynamic, dynamic>> accessLog;

  /// Consent, baseline forms and enrolment status keyed by patient id.
  final Box<Map<dynamic, dynamic>> participants;

  /// Self-reports, usability and feedback responses keyed by response id.
  final Box<Map<dynamic, dynamic>> questionnaires;

  /// Therapist monitoring forms keyed by id.
  final Box<Map<dynamic, dynamic>> monitoring;

  /// Append-only application usage log of patient actions.
  final Box<Map<dynamic, dynamic>> usageLog;

  /// Voice-use monitoring entries keyed by id.
  final Box<Map<dynamic, dynamic>> voiceDiary;

  static Future<LocalDatabase> open({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) async {
    await Hive.initFlutter('melo');
    final cipher = HiveAesCipher(await _loadOrCreateKey(secureStorage));

    Future<Box<Map<dynamic, dynamic>>> records(String name) =>
        Hive.openBox<Map<dynamic, dynamic>>(name, encryptionCipher: cipher);

    return LocalDatabase._(
      users: await records('users'),
      credentials: await Hive.openBox<String>(
        'credentials',
        encryptionCipher: cipher,
      ),
      meta: await Hive.openBox<Object>('meta', encryptionCipher: cipher),
      exercises: await records('exercises'),
      schedules: await records('schedules'),
      completions: await records('completions'),
      recordings: await records('recordings'),
      reminders: await Hive.openBox<List<dynamic>>(
        'reminders',
        encryptionCipher: cipher,
      ),
      accessLog: await records('access_log'),
      participants: await records('participants'),
      questionnaires: await records('questionnaires'),
      monitoring: await records('monitoring'),
      usageLog: await records('usage_log'),
      voiceDiary: await records('voice_diary'),
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
