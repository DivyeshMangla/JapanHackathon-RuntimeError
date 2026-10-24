import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../recordings/data/voice_recorder.dart';
import '../domain/word_audio_device.dart';

class SystemWordAudioDevice implements WordAudioDevice {
  final _recorder = VoiceRecorder();
  final _player = AudioPlayer();
  File? _take, _playback;

  @override
  Future<bool> permission() => _recorder.ensurePermission();
  @override
  Future<void> start() async {
    await stopPlayback();
    await _delete(_take);
    _take = File(
      '${(await getTemporaryDirectory()).path}/useful-take-${const Uuid().v4()}.wav',
    );
    await _recorder.start(_take!.path);
  }

  @override
  Future<Uint8List?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final bytes = await File(path).readAsBytes();
    await _delete(_take);
    _take = null;
    return bytes;
  }

  @override
  Future<void> play(Uint8List bytes) async {
    await stopPlayback();
    final file = File(
      '${(await getTemporaryDirectory()).path}/useful-play-${const Uuid().v4()}.wav',
    );
    _playback = file;
    await file.writeAsBytes(bytes, flush: true);
    await _player.setFilePath(file.path);
    unawaited(
      _player.play().catchError((Object failure, StackTrace stack) {
        AppLogger.error('Useful word playback failed', failure, stack);
      }),
    );
  }

  @override
  Future<void> stopPlayback() async {
    await _player.stop();
    await _delete(_playback);
    _playback = null;
  }

  Future<void> _delete(File? file) async {
    if (file != null && await file.exists()) await file.delete();
  }

  @override
  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
    await _delete(_take);
    await _delete(_playback);
  }
}
