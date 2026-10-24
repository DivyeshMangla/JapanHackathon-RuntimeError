import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/connected_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/action_page.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../recordings/data/voice_recorder.dart';
import '../data/connected_service.dart';
import 'connected_actions.dart';

/// The server accepts takes of up to two minutes.
const _maxTakeSeconds = 120;
const _micSize = 96.0;

/// Records one practice take and hands it to the outbox, which keeps it
/// encrypted on the phone until the upload succeeds.
class RecordPage extends StatefulWidget {
  const RecordPage({
    super.key,
    required this.service,
    required this.planId,
    required this.exerciseId,
  });

  final ConnectedService service;
  final String planId;
  final String exerciseId;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> with ConnectedActions {
  final _recorder = VoiceRecorder();
  Timer? _timer;
  bool _recording = false;
  int _seconds = 0;

  /// The finished take, kept until it is safely in the outbox so a failed
  /// save can be retried without recording again.
  String? _takePath;

  @override
  ConnectedService get service => widget.service;

  @override
  void dispose() {
    _timer?.cancel();
    final take = _takePath;
    unawaited(
      _recorder.dispose().then((_) async {
        // The take is plaintext audio; never leave it behind.
        if (take != null && await File(take).exists()) {
          await File(take).delete();
        }
      }),
    );
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.ensurePermission()) {
      throw const ConnectedFailure(ConnectedFailureReason.microphoneDenied);
    }
    final path =
        '${(await getTemporaryDirectory()).path}/practice-${const Uuid().v4()}.wav';
    await _recorder.start(path);
    if (!mounted) {
      await _recorder.cancel();
      return;
    }
    setState(() {
      _takePath = path;
      _recording = true;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= _maxTakeSeconds) unawaited(run('save', _save));
    });
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    _timer?.cancel();
    if (_recording) {
      _takePath = await _recorder.stop() ?? _takePath;
      if (mounted) setState(() => _recording = false);
    }
    final path = _takePath;
    if (path == null || !await File(path).exists()) {
      throw const ConnectedFailure(ConnectedFailureReason.noRecording);
    }
    final file = File(path);
    await service.saveRecording(
      planId: widget.planId,
      exerciseId: widget.exerciseId,
      audio: await file.readAsBytes(),
      seconds: _seconds.clamp(1, _maxTakeSeconds),
    );
    await file.delete();
    _takePath = null;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final exercise = service.config.exercise(widget.exerciseId);
    final retrying = !_recording && _takePath != null;
    final elapsed = Duration(seconds: _seconds);
    final timer =
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: !busy && !_recording,
      child: ActionPage(
        title: exercise?.name ?? l10n.connectedRecordTitle,
        intro: l10n.connectedRecordIntro,
        onBack: busy || _recording ? null : () => Navigator.pop(context),
        backLabel: l10n.connectedBack,
        error: error,
        actions: [
          PrimaryButton(
            label: label(
              'save',
              _recording
                  ? l10n.connectedStopAndSave
                  : retrying
                  ? l10n.connectedRetrySave
                  : l10n.connectedStartRecording,
            ),
            icon: _recording ? LucideIcons.square : LucideIcons.mic,
            onPressed: _recording || retrying
                ? action('save', _save)
                : action('start', _start),
          ),
        ],
        children: [
          InkCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Semantics(
                  label: _recording ? l10n.connectedRecordingNow : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _recording ? AppColors.ink : AppColors.washTint,
                    ),
                    child: SizedBox.square(
                      dimension: _micSize,
                      child: Icon(
                        LucideIcons.mic,
                        size: _micSize / 2.5,
                        color: _recording ? AppColors.sunshine : AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(timer, style: AppTypography.recordTimer),
              ],
            ),
          ),
          InfoNotice(l10n.connectedRecordQueued, icon: LucideIcons.lock),
        ],
      ),
    );
  }
}
