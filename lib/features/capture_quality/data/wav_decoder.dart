import 'dart:typed_data';

/// Decodes 16-bit PCM WAV to samples in -1..1, keeping the first channel.
/// Walks the RIFF chunks rather than assuming a 44-byte header, since
/// recorders may add chunks before the audio.
({Float32List samples, int sampleRate}) decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  String tag(int offset) => String.fromCharCodes(bytes, offset, offset + 4);
  if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
    throw const FormatException('Not a WAV file');
  }

  int? sampleRate;
  int? channels;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = tag(offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      final format = data.getUint16(body, Endian.little);
      final bits = data.getUint16(body + 14, Endian.little);
      if (format != 1 || bits != 16) {
        throw const FormatException('Only 16-bit PCM WAV is supported');
      }
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
    } else if (id == 'data') {
      if (sampleRate == null || channels == null) break;
      // A recorder stopped abruptly can leave the size unset or too large.
      final end = size == 0 || body + size > bytes.length
          ? bytes.length
          : body + size;
      final frameBytes = 2 * channels;
      final count = (end - body) ~/ frameBytes;
      final samples = Float32List(count);
      for (var i = 0; i < count; i++) {
        samples[i] =
            data.getInt16(body + i * frameBytes, Endian.little) / 32768;
      }
      return (samples: samples, sampleRate: sampleRate);
    }
    // Chunks are padded to an even length.
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV file has no audio data');
}
