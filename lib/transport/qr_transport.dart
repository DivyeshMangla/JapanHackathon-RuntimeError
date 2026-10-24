import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/setup_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/app_typography.dart';
import '../shared/widgets/action_page.dart';
import '../shared/widgets/buttons.dart';
import '../shared/widgets/ink_card.dart';
import 'qr_codec.dart';
import 'sync_envelope.dart';
import 'sync_transport.dart';

String _text(BuildContext context, String key) =>
    SetupStrings.text(Localizations.localeOf(context).languageCode, key);

class QrTransport implements SyncTransport {
  QrTransport(this.context);
  final BuildContext context;
  @override
  Future<bool> send(SyncEnvelope envelope) async {
    final frames = await QrCodec.frames(envelope);
    if (!context.mounted) return false;
    return await Navigator.of(
          context,
        ).push<bool>(MaterialPageRoute(builder: (_) => _QrDisplay(frames))) ??
        false;
  }

  @override
  Future<SyncEnvelope?> receive() => Navigator.of(
    context,
  ).push<SyncEnvelope>(MaterialPageRoute(builder: (_) => const _QrScanner()));
}

class _QrDisplay extends StatefulWidget {
  const _QrDisplay(this.frames);
  final List<String> frames;
  @override
  State<_QrDisplay> createState() => _QrDisplayState();
}

class _QrDisplayState extends State<_QrDisplay> {
  int index = 0;
  bool paused = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted && !paused) {
        setState(() => index = (index + 1) % widget.frames.length);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiFrame = widget.frames.length > 1;
    return ActionPage(
      title: _text(context, 'qrTransfer'),
      intro: _text(context, 'qrKeepOpen'),
      onBack: () => Navigator.pop(context, false),
      backLabel: _text(context, 'back'),
      actions: [
        PrimaryButton(
          label: _text(context, 'otherReceived'),
          icon: LucideIcons.check,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
      children: [
        InkCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              QrImageView(
                data: widget.frames[index],
                size: AppSizes.qrCode,
                backgroundColor: AppColors.surface,
                errorCorrectionLevel: QrErrorCorrectLevel.L,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${_text(context, 'frame')} ${index + 1} / ${widget.frames.length}',
                style: AppTypography.monoSmall,
              ),
            ],
          ),
        ),
        if (multiFrame) ...[
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: _text(context, paused ? 'playFrames' : 'pauseFrames'),
                  icon: paused ? LucideIcons.play : LucideIcons.pause,
                  onPressed: () => setState(() => paused = !paused),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SecondaryButton(
                  label: _text(context, 'nextFrame'),
                  icon: LucideIcons.skipForward,
                  onPressed: () => setState(() {
                    paused = true;
                    index = (index + 1) % widget.frames.length;
                  }),
                ),
              ),
            ],
          ),
          InfoNotice(_text(context, 'fileFaster')),
        ],
      ],
    );
  }
}

class _QrScanner extends StatefulWidget {
  const _QrScanner();
  @override
  State<_QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<_QrScanner> {
  final controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  QrAssembler assembler = QrAssembler();
  bool processing = false;
  String? error;
  @override
  void dispose() {
    unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> detected(BarcodeCapture capture) async {
    if (processing) return;
    final text = capture.barcodes.firstOrNull?.rawValue;
    if (text == null) return;
    processing = true;
    try {
      final result = await assembler.add(text);
      if (!mounted) return;
      if (result != null) {
        Navigator.pop(context, result);
        return;
      }
      setState(() => error = null);
    } catch (_) {
      if (mounted) {
        setState(() => error = _text(context, 'invalidQr'));
      }
    }
    processing = false;
  }

  @override
  Widget build(BuildContext context) {
    final message =
        error ??
        '${assembler.received} / ${assembler.total} '
            '${_text(context, 'framesReceived')}';
    return ActionPage(
      title: _text(context, 'scanQr'),
      onBack: () => Navigator.pop(context),
      backLabel: _text(context, 'back'),
      error: error,
      actions: [
        SecondaryButton(
          label: _text(context, 'restartScan'),
          icon: LucideIcons.rotateCcw,
          onPressed: () => setState(() {
            assembler = QrAssembler();
            error = null;
          }),
        ),
      ],
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.base),
          child: AspectRatio(
            aspectRatio: 1,
            child: MobileScanner(controller: controller, onDetect: detected),
          ),
        ),
        if (error == null)
          Semantics(
            liveRegion: true,
            child: Text(message, style: AppTypography.monoSmall),
          ),
      ],
    );
  }
}
