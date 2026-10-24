import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:melo/data/setup_repository.dart';

void main() {
  test(
    'database authenticates snapshots, resumes from disk, and rotates key on wipe',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'setup-storage-test-',
      );
      Hive.init(directory.path);
      final secrets = MemorySecretStore();
      final key = Hive.generateSecureKey();
      await secrets.write('databaseKey', base64Encode(key));
      var box = await Hive.openBox<String>(
        'setup',
        encryptionCipher: HiveAesCipher(key),
      );
      var repository = EncryptedSetupRepository(
        box,
        secrets,
        await EncryptedSetupRepository.snapshotKey(key),
      );
      try {
        final record = {
          'stage': 'ready',
          'syntheticClinical': 'test-only-secret-marker',
        };
        await repository.save(record);
        expect(await repository.load(), record);
        final bytes = await File(box.path!).readAsBytes();
        expect(
          utf8.decode(bytes, allowMalformed: true),
          isNot(contains('test-only-secret-marker')),
        );
        await box.close();
        box = await Hive.openBox<String>(
          'setup',
          encryptionCipher: HiveAesCipher(key),
        );
        repository = EncryptedSetupRepository(
          box,
          secrets,
          await EncryptedSetupRepository.snapshotKey(key),
        );
        expect(await repository.load(), record);
        final stored = jsonDecode(box.get('snapshot')!) as Map<String, dynamic>;
        final cipher = base64Decode(stored['ciphertext'] as String);
        cipher[0] ^= 1;
        stored['ciphertext'] = base64Encode(cipher);
        await box.put('snapshot', jsonEncode(stored));
        await expectLater(repository.load(), throwsA(anything));
        await repository.wipe();
        expect(await repository.load(), isEmpty);
        expect(await secrets.read('databaseKey'), isNot(base64Encode(key)));
        await repository.save({'stage': 'needsSignup'});
        expect(await repository.load(), {'stage': 'needsSignup'});
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
