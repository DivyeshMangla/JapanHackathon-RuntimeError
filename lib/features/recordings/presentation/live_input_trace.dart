import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n.dart';

/// Recent normalized microphone levels, not a synthesized audio waveform.
class LiveInputTrace extends StatefulWidget {
  const LiveInputTrace({super.key, required this.level});
  final double level;
  @override
  State<LiveInputTrace> createState() => _LiveInputTraceState();
}

class _LiveInputTraceState extends State<LiveInputTrace> {
  static const _capacity = 36;
  late final List<double> _levels = [widget.level.clamp(0, 1)];
  @override
  void didUpdateWidget(LiveInputTrace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _levels.add(widget.level.clamp(0, 1));
    if (_levels.length > _capacity) _levels.removeAt(0);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.recordInputLevel,
    value: '${(widget.level.clamp(0, 1) * 100).round()}%',
    child: SizedBox(
      height: 72,
      child: CustomPaint(painter: _TracePainter(List.of(_levels), _capacity)),
    ),
  );
}

class _TracePainter extends CustomPainter {
  const _TracePainter(this.levels, this.capacity);
  final List<double> levels;
  final int capacity;
  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / capacity;
    for (var i = 0; i < capacity; i++) {
      final sample = i - (capacity - levels.length);
      final level = sample < 0 ? 0.0 : levels[sample];
      final height = 3 + level * (size.height - 3);
      final rect = Rect.fromCenter(
        center: Offset(slot * (i + 0.5), size.height / 2),
        width: slot * .55,
        height: height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..color = sample < 0 ? AppColors.dockSelection : AppColors.sunshine,
      );
    }
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) => true;
}
