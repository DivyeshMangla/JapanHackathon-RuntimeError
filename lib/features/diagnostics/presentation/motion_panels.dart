import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/diagnostic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../capture_quality/domain/motion_analyzer.dart';
import 'controllers/diagnostics_controllers.dart';
import 'widgets/diagnostic_charts.dart';
import 'widgets/scope_widgets.dart';

String _axes(AppLocalizations l10n, Vector3 v) => l10n.axisValues(
  formatDecimal(v.x, 2),
  formatDecimal(v.y, 2),
  formatDecimal(v.z, 2),
);

/// Gyroscope and accelerometer, with a still/moving verdict.
class MotionPanel extends ConsumerWidget {
  const MotionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final motion = ref.watch(motionMonitorProvider);
    final reading = motion.reading;
    if (!motion.available || reading == null) {
      return ScopePanel(
        title: l10n.motionSection,
        child: Text(
          motion.available ? l10n.micStarting : l10n.motionUnavailable,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return ScopePanel(
      title: l10n.motionSection,
      status: ScopeStatus(
        text: reading.moving ? l10n.motionMoving : l10n.motionStill,
        alert: reading.moving,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReadoutGrid(
            children: [
              ScopeReadout(
                label: l10n.gyroLabel,
                value: formatDecimal(reading.gyroRms, 2),
                caption: '${l10n.unitGyroRms}\n${_axes(l10n, reading.gyro)}',
                alert: reading.gyroRms > MotionAnalyzer.gyroThreshold,
              ),
              ScopeReadout(
                label: l10n.accelLabel,
                value: formatDecimal(reading.accelRms, 2),
                caption:
                    '${l10n.unitAccelRms}\n${_axes(l10n, reading.userAccel)}',
                alert: reading.accelRms > MotionAnalyzer.accelThreshold,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ChartLegend(
            entries: [
              (l10n.gyroSeries, DiagnosticColors.trace),
              (l10n.gyroThreshold, DiagnosticColors.alert),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TraceChart(
            series: [
              TraceSeries(
                label: l10n.gyroThreshold,
                values: List.filled(
                  motion.gyroHistory.length,
                  MotionAnalyzer.gyroThreshold,
                ),
                color: DiagnosticColors.alert,
              ),
              TraceSeries(
                label: l10n.gyroSeries,
                values: motion.gyroHistory,
                color: DiagnosticColors.trace,
              ),
            ],
            minY: 0,
            maxY: 1,
            gridValues: const [0, 0.25, 0.5, 0.75, 1],
            formatGrid: (v) => formatDecimal(v, 2),
            capacity: 75,
            semanticLabel: l10n.gyroSemantics,
            height: 110,
          ),
        ],
      ),
    );
  }
}

/// Pitch and roll, compared against a reference angle set by the user.
class OrientationPanel extends ConsumerWidget {
  const OrientationPanel({super.key});

  static const _toleranceDeg = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final motion = ref.watch(motionMonitorProvider);
    final tilt = motion.reading?.tilt;
    final reference = motion.reference;
    final deviation = tilt == null || reference == null
        ? null
        : tilt.deviationFrom(reference);
    final off = deviation != null && deviation > _toleranceDeg;

    return ScopePanel(
      title: l10n.orientationSection,
      status: deviation == null
          ? null
          : ScopeStatus(
              text: l10n.degrees(formatDecimal(deviation, 0)),
              alert: off,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReadoutGrid(
            children: [
              ScopeReadout(
                label: l10n.pitchLabel,
                value: tilt == null
                    ? '--'
                    : l10n.degrees(formatDecimal(tilt.pitchDeg, 1)),
              ),
              ScopeReadout(
                label: l10n.rollLabel,
                value: tilt == null
                    ? '--'
                    : l10n.degrees(formatDecimal(tilt.rollDeg, 1)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            deviation == null
                ? l10n.referenceNone
                : off
                ? l10n.referenceOff(formatDecimal(deviation, 0))
                : l10n.referenceOk(
                    formatDecimal(_toleranceDeg, 0),
                    formatDecimal(deviation, 0),
                  ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: off ? DiagnosticColors.alert : null,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: tilt == null
                  ? null
                  : ref.read(motionMonitorProvider.notifier).setReference,
              icon: const Icon(LucideIcons.crosshair, size: 16),
              label: Text(l10n.setReference),
            ),
          ),
        ],
      ),
    );
  }
}

class ProximityPanel extends ConsumerWidget {
  const ProximityPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final proximity = ref.watch(proximityProvider);
    final near = proximity.value;
    final unavailable =
        proximity.hasError || (proximity.hasValue && near == null);

    return ScopePanel(
      title: l10n.proximitySection,
      status: unavailable || near == null
          ? null
          : ScopeStatus(
              text: near ? l10n.proximityNear : l10n.proximityFar,
              alert: near,
            ),
      child: Text(
        unavailable ? l10n.proximityUnavailable : l10n.proximityHint,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
