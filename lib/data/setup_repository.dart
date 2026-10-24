import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> clear();
}

class AndroidSecretStore implements SecretStore {
  const AndroidSecretStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: 'setup_$key');
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: 'setup_$key', value: value);
  @override
  Future<void> clear() async {
    for (final key in (await _storage.readAll()).keys) {
      if (key.startsWith('setup_') && key != 'setup_resetPending') {
        await _storage.delete(key: key);
      }
    }
  }
}

abstract interface class SetupRepository {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> snapshot);
  Future<void> wipe();
}

/// An encrypted, isolated Hive database. The workflow never opens legacy boxes.
/// A single snapshot makes state and its associated data one atomic Hive write.
class EncryptedSetupRepository implements SetupRepository {
  EncryptedSetupRepository(this.box, this.secrets, this._key);
  Box<String> box;
  final SecretStore secrets;
  SecretKey _key;
  final _cipher = AesGcm.with256bits();
  static Future<SecretKey> snapshotKey(List<int> key) =>
      Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(key),
        info: utf8.encode('setup-database-authentication-v1'),
      );
  static Future<EncryptedSetupRepository> open(SecretStore secrets) async {
    await Hive.initFlutter('offline_setup');
    if (await secrets.read('resetPending') == 'true') {
      await Hive.deleteBoxFromDisk('setup');
      await secrets.clear();
    }
    var key = await secrets.read('databaseKey');
    if (key == null) {
      if (await Hive.boxExists('setup')) {
        throw StateError(
          'Device key is missing. Existing data cannot be opened.',
        );
      }
      key = base64Encode(Hive.generateSecureKey());
      await secrets.write('databaseKey', key);
    }
    return EncryptedSetupRepository(
      await Hive.openBox<String>(
        'setup',
        encryptionCipher: HiveAesCipher(base64Decode(key)),
      ),
      secrets,
      await snapshotKey(base64Decode(key)),
    );
  }

  @override
  Future<Map<String, dynamic>> load() async {
    final stored = box.get('snapshot');
    if (stored == null) return {};
    final data = jsonDecode(stored) as Map<String, dynamic>;
    final plain = await _cipher.decrypt(
      SecretBox(
        base64Decode(data['ciphertext'] as String),
        nonce: base64Decode(data['nonce'] as String),
        mac: Mac(base64Decode(data['mac'] as String)),
      ),
      secretKey: _key,
      aad: utf8.encode('setup-snapshot-v1'),
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> snapshot) async {
    final encrypted = await _cipher.encrypt(
      utf8.encode(jsonEncode(snapshot)),
      secretKey: _key,
      aad: utf8.encode('setup-snapshot-v1'),
    );
    await box.put(
      'snapshot',
      jsonEncode({
        'nonce': base64Encode(encrypted.nonce),
        'ciphertext': base64Encode(encrypted.cipherText),
        'mac': base64Encode(encrypted.mac.bytes),
      }),
    );
    await box.flush();
  }

  @override
  Future<void> wipe() async {
    await box.deleteFromDisk();
    final key = Hive.generateSecureKey();
    await secrets.write('databaseKey', base64Encode(key));
    _key = await snapshotKey(key);
    box = await Hive.openBox<String>(
      'setup',
      encryptionCipher: HiveAesCipher(key),
    );
  }
}

class MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> clear() async =>
      values.removeWhere((key, _) => key != 'resetPending');
}

class MemorySetupRepository implements SetupRepository {
  String _snapshot = '{}';
  @override
  Future<Map<String, dynamic>> load() async =>
      jsonDecode(_snapshot) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> snapshot) async {
    _snapshot = jsonEncode(snapshot);
  }

  @override
  Future<void> wipe() async {
    _snapshot = '{}';
  }
}
