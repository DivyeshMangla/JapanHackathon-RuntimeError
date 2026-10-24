import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'sync_envelope.dart';

/// Frames are bounded UTF-8 strings, not character-count approximations.
class QrCodec {
  static const maxBytes = 1400;
  static const maxFrames = 1200;
  static Future<List<String>> frames(SyncEnvelope envelope) async {
    final text = envelope.encode();
    final bytes = utf8.encode(text);
    if (bytes.length <= maxBytes) return [text];
    if (bytes.length > 1024 * 1024) {
      throw const FormatException('Package too large');
    }
    final encoded = base64Encode(bytes);
    final hash = base64UrlEncode((await Sha256().hash(bytes)).bytes);
    const chunkSize = 1200;
    final count = (encoded.length / chunkSize).ceil();
    if (count > maxFrames) {
      throw const FormatException('Too many QR frames; use file transfer');
    }
    return [
      for (var i = 0; i < count; i++)
        jsonEncode({
          'qr': 1,
          'id': hash,
          'i': i,
          'n': count,
          'data': encoded.substring(
            i * chunkSize,
            (i + 1) * chunkSize > encoded.length
                ? encoded.length
                : (i + 1) * chunkSize,
          ),
        }),
    ];
  }
}

class QrAssembler {
  String? _id;
  int total = 0;
  final _parts = <int, String>{};
  int get received => _parts.length;
  Future<SyncEnvelope?> add(String text) async {
    if (utf8.encode(text).length > QrCodec.maxBytes) {
      throw const FormatException('QR frame too large');
    }
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (!j.containsKey('qr')) return SyncEnvelope.decode(text);
    final count = j['n'] as int;
    final index = j['i'] as int;
    final id = j['id'] as String;
    final part = j['data'] as String;
    if (j['qr'] != 1 ||
        count < 2 ||
        count > QrCodec.maxFrames ||
        index < 0 ||
        index >= count ||
        part.length > 1200 ||
        id.length != 44) {
      throw const FormatException('Invalid QR frame');
    }
    if (_id != null && (_id != id || total != count)) {
      throw const FormatException('Different package: restart scanner');
    }
    _id = id;
    total = count;
    if (_parts.containsKey(index) && _parts[index] != part) {
      throw const FormatException('Conflicting QR frame');
    }
    _parts[index] = part;
    if (_parts.length != total) return null;
    final bytes = base64Decode(List.generate(total, (i) => _parts[i]!).join());
    if (bytes.length > 1024 * 1024 ||
        base64UrlEncode((await Sha256().hash(bytes)).bytes) != _id) {
      throw const FormatException('QR package checksum failed');
    }
    return SyncEnvelope.decode(utf8.decode(bytes));
  }
}
