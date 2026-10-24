import 'dart:convert';

import '../core/canonical_json.dart';

enum EnvelopeType { join, consent, plan }

class SyncEnvelope {
  SyncEnvelope({
    required this.type,
    required this.senderId,
    required this.recipientId,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });
  final EnvelopeType type;
  final String senderId, recipientId, nonce, ciphertext, mac;
  Map<String, dynamic> get header => {
    'version': 1,
    'type': type.name,
    'senderId': senderId,
    'recipientId': recipientId,
  };
  Map<String, dynamic> toJson() => {
    ...header,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };
  String encode() => canonical(toJson());
  static SyncEnvelope decode(String text) {
    if (utf8.encode(text).length > 1024 * 1024) {
      throw const FormatException('Package too large');
    }
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw const FormatException('Unsupported package version');
    }
    return SyncEnvelope(
      type: EnvelopeType.values.byName(j['type'] as String),
      senderId: j['senderId'] as String,
      recipientId: j['recipientId'] as String,
      nonce: j['nonce'] as String,
      ciphertext: j['ciphertext'] as String,
      mac: j['mac'] as String,
    );
  }
}
