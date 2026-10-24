import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/diagnostic_colors.dart';
import '../../domain/live_audio_pipeline.dart';

/// One line on a [TraceChart], with its legend label.
class TraceSeries {
  const TraceSeries({
    required this.label,
    required this.values,
    required this.color,
    this.fillBelow = false,
  });

  final String label;
  final List<double> values;
  final Color color;

  /// Shades the area under the line, used for the noise floor.
  final bool fillBelow;
}

/// Colour swatches naming each series; identity is never colour alone.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.entries});

  final List<(String, Color)> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (label, color) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSpacing.md,
                height: AppSpacing.xs,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.monoMicro.copyWith(
                  color: DiagnosticColors.textDim,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Live waveform: the raw input behind the denoised signal, so the removed
/// noise shows as the dim band the bright trace does not cover.
class WaveformChart extends StatelessWidget {
  const WaveformChart({
    super.key,
    required this.raw,
    required this.clean,
    required this.semanticLabel,
    this.height = 120,
  });

  final List<WaveColumn> raw;
  final List<WaveColumn> clean;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _WaveformPainter(raw: raw, clean: clean),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.raw, required this.clean});

  final List<WaveColumn> raw;
  final List<WaveColumn> clean;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = DiagnosticColors.grid
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    _columns(canvas, size, raw, DiagnosticColors.traceDim);
    _columns(canvas, size, clean, DiagnosticColors.clean);
  }

  void _columns(Canvas canvas, Size size, List<WaveColumn> data, Color color) {
    if (data.isEmpty) return;
    final mid = size.height / 2;
    final step = size.width / data.length;
    final paint = Paint()
      ..color = color
      ..strokeWidth = step.clamp(1.0, 3.0);
    for (var i = 0; i < data.length; i++) {
      final x = i * step + step / 2;
      final top = mid - data[i].max.clamp(-1.0, 1.0) * mid;
      final bottom = mid - data[i].min.clamp(-1.0, 1.0) * mid;
      canvas.drawLine(Offset(x, top), Offset(x, bottom + 1), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.raw != raw || old.clean != clean;
}

/// Line chart of recent values against fixed gridlines, newest on the right.
class TraceChart extends StatelessWidget {
  const TraceChart({
    super.key,
    required this.series,
    required this.minY,
    required this.maxY,
    required this.gridValues,
    required this.formatGrid,
    required this.capacity,
    required this.semanticLabel,
    this.height = 160,
  });

  final List<TraceSeries> series;
  final double minY;
  final double maxY;
  final List<double> gridValues;
  final String Function(double value) formatGrid;

  /// Points that fill the width, so the trace scrolls at a steady rate.
  final int capacity;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _TracePainter(chart: this),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.chart});

  final TraceChart chart;

  static const _axisWidth = 40.0;

  double _y(double value, double height) {
    final t = (value - chart.minY) / (chart.maxY - chart.minY);
    return height - t.clamp(0.0, 1.0) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _axisWidth;
    final grid = Paint()
      ..color = DiagnosticColors.grid
      ..strokeWidth = 1;
    for (final value in chart.gridValues) {
      final y = _y(value, size.height);
      canvas.drawLine(Offset(_axisWidth, y), Offset(size.width, y), grid);
      final label = TextPainter(
        text: TextSpan(
          text: chart.formatGrid(value),
          style: AppTypography.monoMicro.copyWith(
            color: DiagnosticColors.textDim,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _axisWidth - AppSpacing.xs);
      label.paint(canvas, Offset(0, y - label.height / 2));
      label.dispose();
    }

    final step = plotWidth / (chart.capacity - 1);
    for (final series in chart.series) {
      final values = series.values;
      if (values.length < 2) continue;
      final start = _axisWidth + (chart.capacity - values.length) * step;
      final line = Path();
      for (var i = 0; i < values.length; i++) {
        final point = Offset(start + i * step, _y(values[i], size.height));
        i == 0
            ? line.moveTo(point.dx, point.dy)
            : line.lineTo(point.dx, point.dy);
      }
      if (series.fillBelow) {
        final area = Path.from(line)
          ..lineTo(start + (values.length - 1) * step, size.height)
          ..lineTo(start, size.height)
          ..close();
        canvas.drawPath(area, Paint()..color = DiagnosticColors.noiseFill);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = series.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => old.chart.series != chart.series;
}

/// A frequency to mark on a [SpectrumChart], such as detected hum.
typedef SpectrumMarker = ({double frequencyHz, String label});

/// Spectra on a log-frequency axis from [SpectrumView.minHz] to
/// [SpectrumView.maxHz]; every series holds [SpectrumView.points] values.
class SpectrumChart extends StatelessWidget {
  const SpectrumChart({
    super.key,
    required this.series,
    required this.markers,
    required this.semanticLabel,
    this.height = 180,
  });

  static const minDb = -160.0;
  static const maxDb = -40.0;

  final List<TraceSeries> series;
  final List<SpectrumMarker> markers;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _SpectrumPainter(chart: this),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({required this.chart});

  final SpectrumChart chart;

  static const _axisWidth = 40.0;
  static const _axisHeight = 16.0;
  static const _frequencyTicks = [100.0, 1000.0, 10000.0];
  static const _levelTicks = [-140.0, -100.0, -60.0];

  double _x(double hz, double plotWidth) {
    final t =
        log(hz / SpectrumView.minHz) /
        log(SpectrumView.maxHz / SpectrumView.minHz);
    return _axisWidth + t.clamp(0.0, 1.0) * plotWidth;
  }

  double _y(double db, double plotHeight) {
    final t =
        (db - SpectrumChart.minDb) /
        (SpectrumChart.maxDb - SpectrumChart.minDb);
    return plotHeight - t.clamp(0.0, 1.0) * plotHeight;
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.monoMicro.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, 0));
    painter.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - _axisWidth;
    final plotHeight = size.height - _axisHeight;
    final grid = Paint()
      ..color = DiagnosticColors.grid
      ..strokeWidth = 1;

    for (final db in _levelTicks) {
      final y = _y(db, plotHeight);
      canvas.drawLine(Offset(_axisWidth, y), Offset(size.width, y), grid);
      _label(
        canvas,
        db.round().toString(),
        Offset(_axisWidth / 2, y - AppSpacing.sm),
        DiagnosticColors.textDim,
      );
    }
    for (final hz in _frequencyTicks) {
      final x = _x(hz, plotWidth);
      canvas.drawLine(Offset(x, 0), Offset(x, plotHeight), grid);
      _label(
        canvas,
        hz >= 1000 ? '${(hz / 1000).round()}k' : hz.round().toString(),
        Offset(x, plotHeight + AppSpacing.xs / 2),
        DiagnosticColors.textDim,
      );
    }

    for (final marker in chart.markers) {
      final x = _x(marker.frequencyHz, plotWidth);
      final paint = Paint()
        ..color = DiagnosticColors.alert
        ..strokeWidth = 1;
      for (var y = 0.0; y < plotHeight; y += AppSpacing.sm) {
        canvas.drawLine(Offset(x, y), Offset(x, y + AppSpacing.xs), paint);
      }
      _label(canvas, marker.label, Offset(x, 0), DiagnosticColors.alert);
    }

    final step = plotWidth / (SpectrumView.points - 1);
    for (final series in chart.series) {
      final values = series.values;
      if (values.length < 2) continue;
      final line = Path();
      for (var i = 0; i < values.length; i++) {
        final point = Offset(_axisWidth + i * step, _y(values[i], plotHeight));
        i == 0
            ? line.moveTo(point.dx, point.dy)
            : line.lineTo(point.dx, point.dy);
      }
      if (series.fillBelow) {
        final area = Path.from(line)
          ..lineTo(_axisWidth + (values.length - 1) * step, plotHeight)
          ..lineTo(_axisWidth, plotHeight)
          ..close();
        canvas.drawPath(area, Paint()..color = DiagnosticColors.noiseFill);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = series.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.chart.series != chart.series || old.chart.markers != chart.markers;
}
