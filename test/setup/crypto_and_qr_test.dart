import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/crypto/setup_crypto.dart';
import 'package:melo/data/setup_repository.dart';
import 'package:melo/transport/qr_codec.dart';
import 'package:melo/transport/sync_envelope.dart';

import 'setup_test_helpers.dart';

void main() {
  test(
    'X25519 authenticated round trip; wrong recipient, wrong key and tampering fail',
    () async {
      final a = SetupCrypto(MemorySecretStore());
      final b = SetupCrypto(MemorySecretStore());
      final keys = await a.generate(therapist: true);
      await b.generate(therapist: true);
      final e = await b.encrypt(
        type: EnvelopeType.consent,
        senderId: 'patient',
        recipientId: 'therapist-a',
        publicKey: keys['x25519Pub']!,
        payload: {'consent': true},
      );
      final decoded = SyncEnvelope.decode(e.encode());
      expect(decoded.toJson(), e.toJson());
      expect(await a.decrypt(decoded, 'therapist-a'), {'consent': true});
      await expectLater(b.decrypt(decoded, 'therapist-b'), throwsSetupFailure);
      await expectLater(b.decrypt(decoded, 'therapist-a'), throwsA(anything));
      final changed = SyncEnvelope.decode(
        jsonEncode({...e.toJson(), 'senderId': 'attacker'}),
      );
      await expectLater(a.decrypt(changed, 'therapist-a'), throwsA(anything));
      final bytes = base64Decode(e.ciphertext);
      bytes[bytes.length - 1] ^= 1;
      final tampered = SyncEnvelope.decode(
        jsonEncode({...e.toJson(), 'ciphertext': base64Encode(bytes)}),
      );
      await expectLater(a.decrypt(tampered, 'therapist-a'), throwsA(anything));
      final signature = await a.sign({'b': 2, 'a': 1});
      expect(
        await a.verify({'a': 1, 'b': 2}, signature, keys['ed25519Pub']!),
        true,
      );
      expect(
        await a.verify({'a': 9, 'b': 2}, signature, keys['ed25519Pub']!),
        false,
      );
      expect(
        () => SyncEnvelope.decode(jsonEncode({...e.toJson(), 'version': 2})),
        throwsFormatException,
      );
    },
  );

  SyncEnvelope packet(String payload) => SyncEnvelope(
    type: EnvelopeType.plan,
    senderId: 't',
    recipientId: 'p',
    nonce: '',
    ciphertext: payload,
    mac: '',
  );
  test(
    'small QR stays single, large UTF-8 payload reassembles out of order with duplicates',
    () async {
      final small = packet('tiny');
      final one = await QrCodec.frames(small);
      expect(one.length, 1);
      expect((await QrAssembler().add(one.single))!.encode(), small.encode());
      final large = packet(List.filled(10000, 'ਪੰਜਾਬੀ').join());
      final frames = await QrCodec.frames(large);
      expect(frames.length, greaterThan(1));
      expect(
        frames.every((f) => utf8.encode(f).length <= QrCodec.maxBytes),
        true,
      );
      final assembler = QrAssembler();
      await assembler.add(frames.last);
      await assembler.add(frames.last);
      expect(assembler.received, 1);
      SyncEnvelope? result;
      for (final frame in frames.reversed) {
        result = await assembler.add(frame);
      }
      expect(result!.encode(), large.encode());
    },
  );
  test('mixed, invalid and corrupt QR frames are rejected', () async {
    final frames = await QrCodec.frames(packet('a' * 3000));
    final other = await QrCodec.frames(packet('b' * 3000));
    final assembler = QrAssembler();
    await assembler.add(frames.first);
    await expectLater(assembler.add(other.last), throwsFormatException);
    final frame = jsonDecode(frames.first) as Map<String, dynamic>;
    await expectLater(
      QrAssembler().add(jsonEncode({...frame, 'n': 999999})),
      throwsFormatException,
    );
    await expectLater(
      QrAssembler().add(jsonEncode({...frame, 'i': -1})),
      throwsFormatException,
    );
    final corrupt = QrAssembler();
    await corrupt.add(jsonEncode({...frame, 'data': 'AAAA'}));
    await expectLater(() async {
      for (final f in frames.skip(1)) {
        await corrupt.add(f);
      }
    }(), throwsFormatException);
  });
}
