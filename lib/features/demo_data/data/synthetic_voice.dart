import 'dart:math';
import 'dart:typed_data';

/// Builds a 16-bit mono 44.1 kHz WAV of a sustained vowel-like tone so demo
/// recordings can be played back. It is a stand-in, not real speech.
Uint8List syntheticVoiceWav({
  required double seconds,
  required double pitchHz,
  int seed = 0,
}) {
  const sampleRate = 44100;
  final count = (seconds * sampleRate).round();
  final random = Random(seed);
  final samples = Int16List(count);

  var phase = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / sampleRate;
    // Gentle vibrato and a little noise so the tone is not perfectly static.
    final pitch = pitchHz * (1 + 0.012 * sin(2 * pi * 5.2 * t));
    phase += 2 * pi * pitch / sampleRate;

    var value = 0.0;
    for (var harmonic = 1; harmonic <= 8; harmonic++) {
      value += sin(phase * harmonic) / (harmonic * harmonic * 0.6 + 0.4);
    }
    value += (random.nextDouble() - 0.5) * 0.02;

    // 120 ms fade at each end avoids clicks.
    final edge = min(t, seconds - t);
    final envelope = edge < 0.12 ? edge / 0.12 : 1.0;
    samples[i] = (value * envelope * 0.28 * 32767).round().clamp(-32768, 32767);
  }

  final data = samples.buffer.asUint8List();
  final header = ByteData(44)
    ..setUint32(0, 0x52494646) // "RIFF"
    ..setUint32(4, 36 + data.length, Endian.little)
    ..setUint32(8, 0x57415645) // "WAVE"
    ..setUint32(12, 0x666d7420) // "fmt "
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x64617461) // "data"
    ..setUint32(40, data.length, Endian.little);

  return (BytesBuilder(copy: false)
        ..add(header.buffer.asUint8List())
        ..add(data))
      .takeBytes();
}
