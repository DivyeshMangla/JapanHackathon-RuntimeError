import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/system_word_audio_device.dart';
import '../domain/word_audio_device.dart';
import 'word_strings.dart';

/// A foreground-only capture session. It neither uploads nor analyzes audio.
class WordAudioController extends ChangeNotifier with WidgetsBindingObserver {
  WordAudioController({WordAudioDevice? device})
    : _device = device ?? SystemWordAudioDevice() {
    WidgetsBinding.instance.addObserver(this);
  }
  final WordAudioDevice _device;
  bool recording = false, busy = false, _closed = false, _foreground = true;
  String? message;
  Uint8List? audio;
  Future<void>? _starting, _stopping, _playing;

  void _changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> start() {
    if (busy || recording || !_foreground || _closed) return Future.value();
    return _starting = _start();
  }

  Future<void> _start() async {
    busy = true;
    message = null;
    _changed();
    try {
      await _device.stopPlayback();
      if (!await _device.permission()) {
        message = WordStrings.micDenied;
        return;
      }
      if (!_foreground || _closed) return;
      await _device.start();
      recording = true;
      audio = null;
      // A permission sheet or lifecycle change may finish after start began.
      if (!_foreground || _closed) await stop();
    } catch (_) {
      message = WordStrings.error;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> stop() {
    if (_stopping != null) return _stopping!;
    if (!recording) return Future.value();
    final stopped = _stop();
    _stopping = stopped;
    return stopped.whenComplete(() => _stopping = null);
  }

  Future<void> _stop() async {
    busy = true;
    _changed();
    try {
      audio = await _device.stop();
    } catch (_) {
      message = WordStrings.error;
    } finally {
      recording = false;
      busy = false;
      _changed();
    }
  }

  Future<void> clear() async {
    await stopPlayback();
    await _starting;
    if (recording) await stop();
    audio = null;
    message = null;
    _changed();
  }

  Future<void> play(Uint8List bytes) {
    if (recording || busy || _closed || !_foreground) return Future.value();
    return _playing = _play(bytes);
  }

  Future<void> _play(Uint8List bytes) async {
    busy = true;
    _changed();
    try {
      await _device.play(bytes);
      if (_closed || !_foreground) await _device.stopPlayback();
    } catch (_) {
      message = WordStrings.error;
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _device.stopPlayback();
    } catch (_) {
      message = WordStrings.error;
      _changed();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      if (recording) {
        message = WordStrings.interrupted;
        unawaited(stop());
      }
      unawaited(stopPlayback());
    }
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cleanup());
    super.dispose();
  }

  Future<void> _cleanup() async {
    await _starting;
    await _stopping;
    await _playing;
    if (recording) await stop();
    await _device.dispose();
  }
}
