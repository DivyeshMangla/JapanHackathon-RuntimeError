import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'buttons.dart';

/// Fewer points than this is a tap, not a signature.
const _minSignaturePoints = 3;
const _strokeWidth = 2.0;

class SignaturePad extends StatefulWidget {
  const SignaturePad({
    required this.onSave,
    required this.saveLabel,
    required this.savingLabel,
    required this.redoLabel,
    super.key,
  });

  final Future<void> Function(List<int> png) onSave;
  final String saveLabel;
  final String savingLabel;
  final String redoLabel;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _boundary = GlobalKey();
  final _points = <Offset?>[];
  bool _saving = false;

  bool get _signed => _points.whereType<Offset>().length >= _minSignaturePoints;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes != null) await widget.onSave(bytes.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            // The boundary is captured as the signature image, so it paints
            // its own white background rather than relying on the card.
            child: RepaintBoundary(
              key: _boundary,
              child: ColoredBox(
                color: AppColors.surface,
                child: GestureDetector(
                  onPanStart: (d) =>
                      setState(() => _points.add(d.localPosition)),
                  onPanUpdate: (d) =>
                      setState(() => _points.add(d.localPosition)),
                  onPanEnd: (_) => setState(() => _points.add(null)),
                  child: CustomPaint(
                    painter: _SignaturePainter(List.of(_points)),
                    size: const Size(double.infinity, AppSizes.signaturePad),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: widget.redoLabel,
                icon: LucideIcons.eraser,
                onPressed: _saving || _points.isEmpty
                    ? null
                    : () => setState(_points.clear),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryButton(
                label: _saving ? widget.savingLabel : widget.saveLabel,
                onPressed: _signed && !_saving ? _save : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];
      if (from != null && to != null) canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
