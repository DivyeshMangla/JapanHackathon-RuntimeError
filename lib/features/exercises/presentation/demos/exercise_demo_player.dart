import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/l10n.dart';
import '../../../../shared/widgets/ink_card.dart';
import '../../data/clip_cue_speaker.dart';
import '../../domain/cue_speaker.dart';
import '../../domain/exercise_demo.dart';
import 'exercise_demos.dart';

enum _PlayState { ready, running, paused, finished }

/// Plays an exercise's guided animation for the patient's prescribed
/// repetitions: the figure, the current cue with a countdown, and
/// start/pause controls. A voice speaks each cue as it starts, and can be
/// muted. Every animated exercise uses this card, so only the figure
/// changes between them. Nothing plays until the patient starts it, which
/// also keeps the screen still for reduced-motion users.
class ExerciseDemoPlayer extends ConsumerStatefulWidget {
  const ExerciseDemoPlayer({
    super.key,
    required this.demo,
    required this.repetitions,
  });

  final ExerciseDemo demo;
  final int repetitions;

  @override
  ConsumerState<ExerciseDemoPlayer> createState() => _ExerciseDemoPlayerState();
}

class _ExerciseDemoPlayerState extends ConsumerState<ExerciseDemoPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CueSpeaker _speaker;
  var _state = _PlayState.ready;
  var _voiceOn = true;

  /// The repetition and phase last spoken, so each cue is said once.
  (int, DemoPhase)? _spoken;

  int get _repetitions => widget.repetitions < 1 ? 1 : widget.repetitions;

  @override
  void initState() {
    super.initState();
    _speaker = ref.read(cueSpeakerProvider);
    _controller =
        AnimationController(
            vsync: this,
            duration: widget.demo.script.total(_repetitions),
          )
          ..addListener(_speakNewPhase)
          ..addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(ExerciseDemoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.demo.script.total(_repetitions);
  }

  @override
  void dispose() {
    _speaker.stop();
    _controller.dispose();
    super.dispose();
  }

  void _speakNewPhase() {
    if (_state != _PlayState.running) return;
    final position = _position;
    if (position.finished) return;
    final key = (position.repetition, position.phase);
    if (key == _spoken) return;
    _spoken = key;
    if (_voiceOn) _speaker.speak(position.phase.cue);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _state = _PlayState.finished);
    }
  }

  void _toggle() {
    setState(() {
      switch (_state) {
        case _PlayState.running:
          _controller.stop();
          _speaker.stop();
          _state = _PlayState.paused;
        case _PlayState.finished:
          _spoken = null;
          _state = _PlayState.running;
          _controller.forward(from: 0);
        case _PlayState.ready || _PlayState.paused:
          // Resuming repeats the current cue so the patient knows where
          // they are.
          _spoken = null;
          _state = _PlayState.running;
          _controller.forward();
      }
    });
    _speakNewPhase();
  }

  void _restart() {
    _speaker.stop();
    setState(() {
      _controller.reset();
      _spoken = null;
      _state = _PlayState.ready;
    });
  }

  void _toggleVoice() {
    setState(() => _voiceOn = !_voiceOn);
    if (!_voiceOn) {
      _speaker.stop();
    } else {
      _spoken = null;
      _speakNewPhase();
    }
  }

  DemoPosition get _position => widget.demo.script.positionAt(
    _controller.duration! * _controller.value,
    _repetitions,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final position = _position;
          final running = _state == _PlayState.running;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DemoHeader(repetition: position.repetition, total: _repetitions),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                image: true,
                label: widget.demo.description(l10n),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: CustomPaint(
                    painter: widget.demo.painter(context, position, running),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DemoCue(state: _state, position: position),
              const SizedBox(height: AppSpacing.lg),
              _DemoControls(
                state: _state,
                voiceOn: _voiceOn,
                onToggle: _toggle,
                onRestart: _restart,
                onToggleVoice: _toggleVoice,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DemoHeader extends StatelessWidget {
  const _DemoHeader({required this.repetition, required this.total});

  final int repetition;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSpacing.sm,
                height: AppSpacing.sm,
                decoration: const BoxDecoration(
                  color: AppColors.purple,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.demoTitle,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          l10n.demoRepetition(repetition, total),
          style: AppTypography.monoSmall.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

/// What to do now, how long is left of it, and a one-line coaching hint.
class _DemoCue extends StatelessWidget {
  const _DemoCue({required this.state, required this.position});

  final _PlayState state;
  final DemoPosition position;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final active = state == _PlayState.running || state == _PlayState.paused;
    final (title, hint) = switch (state) {
      _PlayState.ready => (l10n.demoReady, l10n.demoReadyHint),
      _PlayState.finished => (l10n.demoFinished, l10n.demoFinishedHint),
      _ => (
        l10n.demoCueLabel(position.phase.cue),
        l10n.demoCueHint(position.phase.cue),
      ),
    };
    final seconds = (position.remaining.inMilliseconds / 1000).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(title, style: text.headlineMedium),
              ),
            ),
            if (active)
              ExcludeSemantics(
                child: Text(
                  l10n.demoCountdown(seconds),
                  style: AppTypography.monoHeadline,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: active ? position.progress : 0,
            minHeight: AppSizes.progressThin,
            color: AppColors.ink,
            backgroundColor: AppColors.washTint,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(hint, style: text.bodySmall?.copyWith(color: AppColors.muted)),
      ],
    );
  }
}

class _DemoControls extends StatelessWidget {
  const _DemoControls({
    required this.state,
    required this.voiceOn,
    required this.onToggle,
    required this.onRestart,
    required this.onToggleVoice,
  });

  final _PlayState state;
  final bool voiceOn;
  final VoidCallback onToggle;
  final VoidCallback onRestart;
  final VoidCallback onToggleVoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, icon) = switch (state) {
      _PlayState.ready => (l10n.demoStart, LucideIcons.play),
      _PlayState.running => (l10n.demoPause, LucideIcons.pause),
      _PlayState.paused => (l10n.demoResume, LucideIcons.play),
      _PlayState.finished => (l10n.demoAgain, LucideIcons.rotateCcw),
    };
    final canRestart =
        state == _PlayState.running || state == _PlayState.paused;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
            ),
            icon: Icon(icon, size: 18),
            label: Text(label),
          ),
        ),
        if (canRestart) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: l10n.demoRestart,
            onPressed: onRestart,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(AppSizes.minTouchTarget),
              backgroundColor: AppColors.washTint,
              foregroundColor: AppColors.ink,
            ),
            icon: const Icon(LucideIcons.rotateCcw, size: 20),
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: voiceOn ? l10n.demoVoiceMute : l10n.demoVoiceUnmute,
          onPressed: onToggleVoice,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(AppSizes.minTouchTarget),
            backgroundColor: AppColors.washTint,
            foregroundColor: AppColors.ink,
          ),
          icon: Icon(
            voiceOn ? LucideIcons.volume2 : LucideIcons.volumeOff,
            size: 20,
          ),
        ),
      ],
    );
  }
}
