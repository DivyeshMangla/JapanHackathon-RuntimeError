import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/diagnostic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../capture_quality/domain/noise_profiler.dart';
import 'controllers/diagnostics_controllers.dart';
import 'widgets/diagnostic_charts.dart';
import 'widgets/scope_widgets.dart';

/// Input, learned noise and denoised spectra, with detected hum and tones
/// marked.
class SpectrumPanel extends StatelessWidget {
  const SpectrumPanel({super.key, required this.monitor});

  final AudioMonitorState monitor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spectrum = monitor.spectrum;
    final report = monitor.noiseReport;
    final markers = <SpectrumMarker>[
      if (report?.hum case final hum? when report!.hasHum)
        (
          frequencyHz: hum.frequencyHz,
          label: l10n.hertz(formatDecimal(hum.frequencyHz, 0)),
        ),
      if (report?.tone case final tone? when report!.hasTone)
        (
          frequencyHz: tone.frequencyHz,
          label: l10n.hertz(formatDecimal(tone.frequencyHz, 0)),
        ),
    ];

    return ScopePanel(
      title: l10n.spectrumTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChartLegend(
            entries: [
              (l10n.spectrumInput, DiagnosticColors.trace),
              (l10n.spectrumNoise, DiagnosticColors.amber),
              (l10n.waveClean, DiagnosticColors.clean),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SpectrumChart(
            series: [
              if (spectrum != null) ...[
                TraceSeries(
                  label: l10n.spectrumNoise,
                  values: spectrum.noise,
                  color: DiagnosticColors.amber,
                  fillBelow: true,
                ),
                TraceSeries(
                  label: l10n.spectrumInput,
                  values: spectrum.input,
                  color: DiagnosticColors.trace,
                ),
                TraceSeries(
                  label: l10n.waveClean,
                  values: spectrum.clean,
                  color: DiagnosticColors.clean,
                ),
              ],
            ],
            markers: markers,
            semanticLabel: l10n.spectrumSemantics,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.spectrumNote, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Which kinds of noise make up the background, each with the measurement
/// behind the verdict.
class NoiseTypesPanel extends StatelessWidget {
  const NoiseTypesPanel({super.key, required this.report});

  final NoiseReport? report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = this.report ?? const NoiseReport(ready: false);
    String peak(SpectralPeak? peak) => peak == null
        ? l10n.noneLabel
        : l10n.noisePeak(
            formatDecimal(peak.frequencyHz, 0),
            formatDecimal(peak.prominenceDb, 0),
          );
    final spectral = report.ready;
    final rows = [
      (
        l10n.noiseRumble,
        l10n.noiseRumbleHint,
        spectral ? l10n.noiseShare(formatPercent(report.rumbleShare)) : '--',
        report.hasRumble,
      ),
      (
        l10n.noiseHum,
        l10n.noiseHumHint,
        spectral ? peak(report.hum) : '--',
        report.hasHum,
      ),
      (
        l10n.noiseTone,
        l10n.noiseToneHint,
        spectral ? peak(report.tone) : '--',
        report.hasTone,
      ),
      (
        l10n.noiseBroadband,
        l10n.noiseBroadbandHint,
        spectral
            ? l10n.noiseBands(
                report.broadbandBands,
                NoiseReport.broadbandTotalBands,
              )
            : '--',
        report.isBroadband,
      ),
      (
        l10n.noiseFluctuating,
        l10n.noiseFluctuatingHint,
        switch (report.fluctuationDb) {
          final spread? => l10n.noiseSpread(formatDecimal(spread, 1)),
          null => '--',
        },
        report.isFluctuating,
      ),
      (
        l10n.noiseTransient,
        l10n.noiseTransientHint(NoiseReport.transientWindowSec),
        report.transients.toString(),
        report.hasTransients,
      ),
    ];
    final found = rows.where((row) => row.$4).length;

    return ScopePanel(
      title: l10n.noiseTypesTitle,
      status: spectral
          ? ScopeStatus(text: l10n.noiseFoundCount(found), alert: found > 0)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!spectral) ...[
            Text(
              l10n.noiseLearning,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          for (final (label, hint, value, detected) in rows)
            _NoiseTypeRow(
              label: label,
              hint: hint,
              value: value,
              detected: detected,
            ),
        ],
      ),
    );
  }
}

class _NoiseTypeRow extends StatelessWidget {
  const _NoiseTypeRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.detected,
  });

  final String label;
  final String hint;
  final String value;
  final bool detected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = detected ? DiagnosticColors.amber : DiagnosticColors.textDim;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.monoSmall.copyWith(
                    color: detected
                        ? DiagnosticColors.amber
                        : DiagnosticColors.text,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  hint,
                  style: AppTypography.monoMicro.copyWith(
                    color: DiagnosticColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTypography.monoSmall.copyWith(color: color),
              ),
              Text(
                (detected ? l10n.foundLabel : l10n.clearLabel).toUpperCase(),
                style: AppTypography.monoMicro.copyWith(
                  color: color,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
