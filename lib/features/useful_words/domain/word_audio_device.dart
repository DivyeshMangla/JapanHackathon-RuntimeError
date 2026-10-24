import 'dart:typed_data';

/// Platform capture/playback only; no delivery or recognition belongs here.
abstract interface class WordAudioDevice {
  Future<bool> permission();
  Future<void> start();
  Future<Uint8List?> stop();
  Future<void> play(Uint8List bytes);
  Future<void> stopPlayback();
  Future<void> dispose();
}
