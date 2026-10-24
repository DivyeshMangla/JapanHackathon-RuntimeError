import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/errors/setup_failure.dart';

abstract interface class NarrationSource {
  Future<void> play(
    String textId,
    String locale,
    String text,
    void Function(int, int) onWord,
  );
  Future<void> stop();
  Future<void> dispose();
}

class OfflineNarrationSource implements NarrationSource {
  AudioPlayer? _audio;
  FlutterTts? _engine;
  AudioPlayer get _player => _audio ??= AudioPlayer();
  FlutterTts get _tts => _engine ??= FlutterTts();
  @override
  Future<void> play(
    String textId,
    String locale,
    String text,
    void Function(int, int) onWord,
  ) async {
    await stop();
    final path = 'assets/audio/narration/$textId-$locale.mp3';
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    if (manifest.listAssets().contains(path)) {
      await _player.setAsset(path);
      await _player.play();
      return;
    }
    final language = {'en': 'en-IN', 'hi': 'hi-IN', 'pa': 'pa-IN'}[locale]!;
    // Explicitly exclude network voices, including the system default voice.
    final voices = await _tts.getVoices;
    if (voices is! List) {
      throw const SetupFailure(SetupFailureReason.narrationUnavailable);
    }
    final matching = voices.whereType<Map<Object?, Object?>>().where(
      (v) =>
          (v['locale'] as String? ?? '')
              .replaceAll('_', '-')
              .startsWith(language.substring(0, 2)) &&
          (v['network_required'] == '0' ||
              v['network_required'] == 'false' ||
              v['network_required'] == false),
    );
    if (matching.isEmpty) {
      throw const SetupFailure(SetupFailureReason.offlineVoiceMissing);
    }
    final voice = matching.first;
    await _tts.setLanguage(language);
    final selected = await _tts.setVoice({
      'name': voice['name'] as String,
      'locale': voice['locale'] as String,
    });
    if (selected != 1) {
      throw const SetupFailure(SetupFailureReason.offlineVoiceMissing);
    }
    _tts.setProgressHandler(
      (String text, int start, int end, String word) => onWord(start, end),
    );
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _engine?.stop();
    await _audio?.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _audio?.dispose();
  }
}
