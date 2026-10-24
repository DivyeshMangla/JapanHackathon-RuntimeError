import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';

/// Encrypts recordings at rest with AES-256-GCM.
///
/// File layout: the 4-byte magic "VPA1", a 12-byte nonce, the ciphertext,
/// then the 16-byte GCM tag. The magic is also the associated data, so a
/// file from a different format version fails authentication.
///
/// The key is generated on first use and kept only in the platform keystore,
/// separate from the Hive database key.
class RecordingVault {
  RecordingVault({FlutterSecureStorage storage = const FlutterSecureStorage()})
    : _storage = storage;

  static const _keyName = 'recording_key_v1';
  static const extension = '.vpa';
  static final _magic = Uint8List.fromList(ascii.encode('VPA1'));

  final FlutterSecureStorage _storage;
  List<int>? _key;

  Future<List<int>> _loadKey() async {
    final cached = _key;
    if (cached != null) return cached;
    final stored = await _storage.read(key: _keyName);
    if (stored != null) return _key = base64Url.decode(stored);

    final key = SecretKeyData.random(length: 32).bytes;
    await _storage.write(key: _keyName, value: base64Url.encode(key));
    return _key = key;
  }

  /// Encrypts [plainPath] into [targetPath], then deletes the plaintext.
  Future<void> encryptFile(String plainPath, String targetPath) =>
      guard(() async {
        final key = await _loadKey();
        final plain = await File(plainPath).readAsBytes();
        final sealed = await Isolate.run(() => seal(plain, key));
        await File(targetPath).writeAsBytes(sealed, flush: true);
        await File(plainPath).delete();
      }, RecordingFailure.new);

  /// Encrypts in-memory WAV bytes straight to [targetPath].
  Future<void> writeEncrypted(Uint8List plain, String targetPath) =>
      guard(() async {
        final key = await _loadKey();
        final sealed = await Isolate.run(() => seal(plain, key));
        await File(targetPath).writeAsBytes(sealed, flush: true);
      }, RecordingFailure.new);

  /// Decrypts [encryptedPath] to a temporary WAV for playback. Callers must
  /// pass the result to [deleteTemporary] when playback ends.
  Future<String> decryptForPlayback(String encryptedPath) =>
      guard(() => _decryptToTemporary(encryptedPath), PlaybackFailure.new);

  Future<String> _decryptToTemporary(String encryptedPath) async {
    final key = await _loadKey();
    final sealed = await File(encryptedPath).readAsBytes();
    final plain = await Isolate.run(() => open(sealed, key));
    final dir = await _playbackDirectory();
    final name = encryptedPath.split(Platform.pathSeparator).last;
    final target = File(
      '${dir.path}${Platform.pathSeparator}'
      '${name.replaceAll(extension, '')}',
    );
    await target.writeAsBytes(plain, flush: true);
    return target.path;
  }

  Future<void> deleteTemporary(String path) => guard(() async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }, PlaybackFailure.new);

  /// Removes any decrypted copies left behind, e.g. after a crash.
  Future<void> clearTemporaryFiles() => guard(() async {
    final dir = await _playbackDirectory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }, PlaybackFailure.new);

  static bool isEncrypted(String path) => path.endsWith(extension);

  Future<Directory> _playbackDirectory() async {
    final temp = await getTemporaryDirectory();
    return Directory(
      '${temp.path}${Platform.pathSeparator}playback',
    ).create(recursive: true);
  }

  @visibleForTesting
  static Future<Uint8List> seal(Uint8List plain, List<int> key) async {
    final box = await DartAesGcm.with256bits().encrypt(
      plain,
      secretKey: SecretKeyData(key),
      aad: _magic,
    );
    return (BytesBuilder(copy: false)
          ..add(_magic)
          ..add(box.concatenation()))
        .takeBytes();
  }

  @visibleForTesting
  static Future<Uint8List> open(Uint8List sealed, List<int> key) async {
    if (sealed.length < 4 + 12 + 16 ||
        ascii.decode(sealed.sublist(0, 4), allowInvalid: true) != 'VPA1') {
      throw const FormatException('Not an encrypted Melo recording');
    }
    final box = SecretBox.fromConcatenation(
      sealed.sublist(4),
      nonceLength: 12,
      macLength: 16,
    );
    final plain = await DartAesGcm.with256bits().decrypt(
      box,
      secretKey: SecretKeyData(key),
      aad: _magic,
    );
    return Uint8List.fromList(plain);
  }
}
