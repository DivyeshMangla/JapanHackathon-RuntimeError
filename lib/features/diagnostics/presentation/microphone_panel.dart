import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/diagnostic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../capture_quality/domain/audio_analyzer.dart';
import '../../capture_quality/domain/take_quality.dart';
import 'controllers/diagnostics_controllers.dart';
import 'noise_panels.dart';
import 'widgets/diagnostic_charts.dart';
import 'widgets/scope_widgets.dart';

/// Live microphone: waveform and level before and after noise removal, the
/// spectrum, the kinds of background noise, and the research doc 4.3
/// quality checks. Listening starts automatically when the screen opens.
class MicrophonePanel extends ConsumerWidget {
  const MicrophonePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final monitor = ref.watch(audioMonitorProvider);
    final note = switch (monitor.status) {
      MonitorStatus.denied => l10n.micDenied,
      MonitorStatus.failed => l10n.failureSensor,
      _ when monitor.levelHistory.isEmpty => l10n.micStarting,
      _ => null,
    };
    final live = monitor.status == MonitorStatus.listening;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WaveformPanel(monitor: monitor, live: live),
        if (note != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(note, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        _LevelPanel(monitor: monitor),
        const SizedBox(height: AppSpacing.md),
        SpectrumPanel(monitor: monitor),
        const SizedBox(height: AppSpacing.md),
        NoiseTypesPanel(report: monitor.noiseReport),
        const SizedBox(height: AppSpacing.md),
        _QualityPanel(monitor: monitor),
      ],
    );
  }
}

class _WaveformPanel extends StatelessWidget {
  const _WaveformPanel({required this.monitor, required this.live});

  final AudioMonitorState monitor;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ScopePanel(
      title: l10n.waveformTitle,
      status: ScopeStatus(
        text: live ? l10n.liveLabel : l10n.offLabel,
        alert: !live,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartLegend(
            entries: [
              (l10n.waveRaw, DiagnosticColors.traceDim),
              (l10n.waveClean, DiagnosticColors.clean),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          WaveformChart(
            raw: monitor.rawWave,
            clean: monitor.cleanWave,
            semanticLabel: l10n.waveSemantics,
            height: 140,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            monitor.voiced ? l10n.voiceDetected : l10n.backgroundOnly,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: monitor.voiced
                  ? DiagnosticColors.trace
                  : DiagnosticColors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPanel extends StatelessWidget {
  const _LevelPanel({required this.monitor});

  final AudioMonitorState monitor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final threshold = [
      for (final floor in monitor.floorHistory)
        floor + AudioAnalyzer.voiceMarginDb,
    ];
    return ScopePanel(
      title: l10n.levelTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartLegend(
            entries: [
              (l10n.levelInput, DiagnosticColors.trace),
              (l10n.waveClean, DiagnosticColors.clean),
              (l10n.levelFloor, DiagnosticColors.amber),
              (l10n.levelVoiceThreshold, DiagnosticColors.traceDim),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TraceChart(
            series: [
              TraceSeries(
                label: l10n.levelFloor,
                values: monitor.floorHistory,
                color: DiagnosticColors.amber,
                fillBelow: true,
              ),
              TraceSeries(
                label: l10n.levelVoiceThreshold,
                values: threshold,
                color: DiagnosticColors.traceDim,
              ),
              TraceSeries(
                label: l10n.levelInput,
                values: monitor.levelHistory,
                color: DiagnosticColors.trace,
              ),
              TraceSeries(
                label: l10n.waveClean,
                values: monitor.cleanLevelHistory,
                color: DiagnosticColors.clean,
              ),
            ],
            minY: -90,
            maxY: 0,
            gridValues: const [-80, -60, -40, -20, 0],
            formatGrid: (v) => formatDecimal(v, 0),
            capacity: 430,
            semanticLabel: l10n.levelSemantics,
          ),
        ],
      ),
    );
  }
}

class _QualityPanel extends StatelessWidget {
  const _QualityPanel({required this.monitor});

  final AudioMonitorState monitor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final quality = monitor.quality;
    final snr = quality?.snrDb;
    final floor = quality?.noiseFloorDb;
    final cleanSnr = monitor.cleaning?.cleanSnrDb;
    final removed = monitor.cleaning?.noiseRemovedDb;
    final clipping = quality?.clippedFraction ?? 0;
    final clipped = clipping >= TakeQuality.maxClippedFraction;
    String db(double? value) =>
        value == null ? '--' : l10n.decibels(formatDecimal(value, 0));

    return ScopePanel(
      title: l10n.snrLabel,
      child: ReadoutGrid(
        children: [
          ScopeReadout(
            label: l10n.noiseFloorLabel,
            value: floor == null
                ? '--'
                : l10n.decibelsFs(formatDecimal(floor, 0)),
          ),
          ScopeReadout(
            label: l10n.snrLabel,
            value: db(snr),
            alert: snr != null && snr < TakeQuality.minSnrDb,
            caption: snr == null
                ? l10n.snrWaiting
                : snr >= TakeQuality.goodSnrDb
                ? l10n.snrGood(formatDecimal(TakeQuality.goodSnrDb, 0))
                : snr >= TakeQuality.minSnrDb
                ? l10n.snrFair
                : l10n.snrPoor(formatDecimal(TakeQuality.minSnrDb, 0)),
          ),
          ScopeReadout(
            label: l10n.noiseRemovedLabel,
            value: db(removed),
            caption: l10n.noiseRemovedCaption,
          ),
          ScopeReadout(
            label: l10n.cleanSnrLabel,
            value: db(cleanSnr),
            caption: l10n.cleanSnrCaption,
          ),
          ScopeReadout(
            label: l10n.phonationLabel,
            value: l10n.seconds(formatDecimal(quality?.phonationSec ?? 0, 1)),
            caption: l10n.phonationLongest(
              formatDecimal(quality?.longestPhonationSec ?? 0, 1),
            ),
          ),
          ScopeReadout(
            label: l10n.clippingLabel,
            value: formatPercent(clipping),
            alert: clipped,
            caption: clipped ? l10n.clippingHigh : l10n.clippingOk,
          ),
        ],
      ),
    );
  }
}
