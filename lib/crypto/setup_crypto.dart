import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../core/canonical_json.dart';
import '../core/errors/setup_failure.dart';
import '../data/setup_repository.dart';
import '../transport/sync_envelope.dart';

class SetupCrypto {
  SetupCrypto(this.secrets);
  final SecretStore secrets;
  final _signer = Ed25519();
  final _exchange = X25519();
  final _cipher = AesGcm.with256bits();

  Future<SimpleKeyPairData> _key(String name, KeyPairType type) async {
    final stored = await secrets.read(name);
    if (stored == null) throw StateError('Device key missing');
    final j = jsonDecode(stored) as Map<String, dynamic>;
    return SimpleKeyPairData(
      base64Decode(j['private'] as String),
      publicKey: SimplePublicKey(
        base64Decode(j['public'] as String),
        type: type,
      ),
      type: type,
    );
  }

  Future<String> _ensure(
    String name,
    SimpleKeyPair key,
    KeyPairType type,
  ) async {
    if (await secrets.read(name) == null) {
      final data = await key.extract();
      await secrets.write(
        name,
        jsonEncode({
          'private': base64Encode(data.bytes),
          'public': base64Encode(data.publicKey.bytes),
        }),
      );
    }
    return base64Encode((await _key(name, type)).publicKey.bytes);
  }

  Future<Map<String, String>> generate({required bool therapist}) async => {
    'ed25519Pub': await _ensure(
      'signing',
      await _signer.newKeyPair(),
      KeyPairType.ed25519,
    ),
    if (therapist)
      'x25519Pub': await _ensure(
        'encryption',
        await _exchange.newKeyPair(),
        KeyPairType.x25519,
      ),
  };
  Future<String> sign(Object value) async => base64Encode(
    (await _signer.sign(
      utf8.encode(canonical(value)),
      keyPair: await _key('signing', KeyPairType.ed25519),
    )).bytes,
  );
  Future<bool> verify(Object value, String signature, String publicKey) =>
      _signer.verify(
        utf8.encode(canonical(value)),
        signature: Signature(
          base64Decode(signature),
          publicKey: SimplePublicKey(
            base64Decode(publicKey),
            type: KeyPairType.ed25519,
          ),
        ),
      );

  Future<SecretKey> _derive(
    SecretKey shared,
    List<int> nonce,
    String context,
  ) async {
    if ((await shared.extractBytes()).every((byte) => byte == 0)) {
      throw const FormatException('Invalid X25519 public key');
    }
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: nonce,
      info: utf8.encode('voice-setup-v1:$context'),
    );
  }

  Future<SyncEnvelope> encrypt({
    required EnvelopeType type,
    required String senderId,
    required String recipientId,
    required String publicKey,
    required Object payload,
  }) async {
    final ephemeral = await _exchange.newKeyPair();
    final shared = await _exchange.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: SimplePublicKey(
        base64Decode(publicKey),
        type: KeyPairType.x25519,
      ),
    );
    final nonce = _cipher.newNonce();
    final header = {
      'version': 1,
      'type': type.name,
      'senderId': senderId,
      'recipientId': recipientId,
    };
    final box = await _cipher.encrypt(
      utf8.encode(canonical(payload)),
      secretKey: await _derive(shared, nonce, canonical(header)),
      nonce: nonce,
      aad: utf8.encode(canonical(header)),
    );
    // First 32 ciphertext bytes carry the ephemeral X25519 public key.
    return SyncEnvelope(
      type: type,
      senderId: senderId,
      recipientId: recipientId,
      nonce: base64Encode(nonce),
      ciphertext: base64Encode([
        ...(await ephemeral.extractPublicKey()).bytes,
        ...box.cipherText,
      ]),
      mac: base64Encode(box.mac.bytes),
    );
  }

  Future<Map<String, dynamic>> decrypt(SyncEnvelope e, String ownId) async {
    if (e.recipientId != ownId) {
      throw const SetupFailure(SetupFailureReason.wrongRecipient);
    }
    final bytes = base64Decode(e.ciphertext);
    if (bytes.length < 33) {
      throw const FormatException('Invalid encrypted package');
    }
    final shared = await _exchange.sharedSecretKey(
      keyPair: await _key('encryption', KeyPairType.x25519),
      remotePublicKey: SimplePublicKey(
        bytes.sublist(0, 32),
        type: KeyPairType.x25519,
      ),
    );
    final nonce = base64Decode(e.nonce);
    final plain = await _cipher.decrypt(
      SecretBox(bytes.sublist(32), nonce: nonce, mac: Mac(base64Decode(e.mac))),
      secretKey: await _derive(shared, nonce, canonical(e.header)),
      aad: utf8.encode(canonical(e.header)),
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }
}
