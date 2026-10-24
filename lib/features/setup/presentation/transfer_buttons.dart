import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/buttons.dart';

/// The QR and file pair offered wherever a package moves between phones.
class TransferButtons extends StatelessWidget {
  const TransferButtons({
    super.key,
    required this.sending,
    required this.qrLabel,
    required this.fileLabel,
    required this.onQr,
    required this.onFile,
    this.emphasised = true,
  });

  final bool sending;
  final String qrLabel;
  final String fileLabel;
  final VoidCallback? onQr;
  final VoidCallback? onFile;

  /// False when another action on the page is the main one.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final qrIcon = sending ? LucideIcons.qrCode : LucideIcons.scanLine;
    final fileIcon = sending ? LucideIcons.fileDown : LucideIcons.fileUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (emphasised)
          PrimaryButton(label: qrLabel, icon: qrIcon, onPressed: onQr)
        else
          SecondaryButton(label: qrLabel, icon: qrIcon, onPressed: onQr),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(label: fileLabel, icon: fileIcon, onPressed: onFile),
      ],
    );
  }
}
