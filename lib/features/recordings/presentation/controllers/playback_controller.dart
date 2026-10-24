import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../audit/domain/access_log.dart';
import '../../../audit/presentation/controllers/access_log_controllers.dart';
import '../../data/recording_repository_providers.dart';
import '../../data/recording_vault.dart';
import '../../domain/recording.dart';

/// Something the player can play: a saved recording (encrypted, and logged
/// when played) or the unsaved draft being reviewed.
class PlaybackSource {
  const PlaybackSource._({
    required this.key,
    required this.path,
    required this.encrypted,
    this.auditTarget,
  });

  factory PlaybackSource.recording(Recording recording, {String? label}) =>
      PlaybackSource._(
        key: recording.id,
        path: recording.filePath,
        encrypted: RecordingVault.isEncrypted(recording.filePath),
        auditTarget:
            '${label ?? recording.patientId} ${recording.kind.name} '
            '${recording.task.name} (${recording.id})',
      );

  factory PlaybackSource.draft(String path) =>
      PlaybackSource._(key: 'draft:$path', path: path, encrypted: false);

  final String key;
  final String path;
  final bool encrypted;

  /// Written to the access log on first play; null for drafts.
  final String? auditTarget;
}

class PlaybackState {
  const PlaybackState({
    this.key,
    this.playing = false,
    this.position = Duration.zero,
  });

  /// The source currently loaded, if any.
  final String? key;
  final bool playing;
  final Duration position;

  bool isPlaying(PlaybackSource source) => playing && key == source.key;

  Duration positionOf(PlaybackSource source) =>
      key == source.key ? position : Duration.zero;
}

/// One shared player for the whole app, so starting one recording stops any
/// other. Encrypted recordings are decrypted to a temporary file only while
/// loaded; the copy is deleted as soon as another source loads or playback
/// is released.
final playbackProvider = NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);

class PlaybackController extends Notifier<PlaybackState> {
  late final AudioPlayer _player;
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _temporaryPath;

  @override
  PlaybackState build() {
    _player = AudioPlayer();
    _subscriptions
      ..add(
        _player.playerStateStream.listen((player) {
          if (player.processingState == ProcessingState.completed) {
            unawaited(_rewind());
          } else {
            state = PlaybackState(
              key: state.key,
              playing: player.playing,
              position: _player.position,
            );
          }
        }),
      )
      ..add(
        _player.positionStream.listen(
          (position) => state = PlaybackState(
            key: state.key,
            playing: state.playing,
            position: position,
          ),
        ),
      );
    ref.onDispose(() {
      for (final s in _subscriptions) {
        unawaited(s.cancel());
      }
      unawaited(_player.dispose());
      unawaited(_deleteTemporary());
    });
    return const PlaybackState();
  }

  /// Plays [source], pausing instead if it is already playing.
  Future<void> toggle(PlaybackSource source) async {
    if (state.isPlaying(source)) {
      await _player.pause();
      return;
    }
    if (state.key != source.key) await _load(source);
    // play() completes only when playback stops, so it is not awaited.
    unawaited(_player.play());
  }

  /// Unloads the player and removes any decrypted copy, e.g. before the file
  /// it holds is moved or deleted.
  Future<void> release() async {
    await _player.stop();
    await _deleteTemporary();
    state = const PlaybackState();
  }

  Future<void> _load(PlaybackSource source) async {
    await _player.stop();
    await _deleteTemporary();
    var path = source.path;
    if (source.encrypted) {
      path = await ref.read(recordingVaultProvider).decryptForPlayback(path);
      _temporaryPath = path;
    }
    await _player.setFilePath(path);
    state = PlaybackState(key: source.key);

    final target = source.auditTarget;
    if (target != null) {
      await ref
          .read(accessLoggerProvider)
          .record(AccessAction.playback, target);
    }
  }

  Future<void> _deleteTemporary() async {
    final path = _temporaryPath;
    if (path == null) return;
    _temporaryPath = null;
    await ref.read(recordingVaultProvider).deleteTemporary(path);
  }

  Future<void> _rewind() async {
    await _player.pause();
    await _player.seek(Duration.zero);
    state = PlaybackState(key: state.key);
  }
}
