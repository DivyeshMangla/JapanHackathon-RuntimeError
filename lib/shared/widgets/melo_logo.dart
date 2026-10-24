import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/l10n.dart';

/// The full Melo logo: wordmark, drops and tagline. The PNG is rendered from
/// assets/branding/melo-logo.svg by tool/generate_logo.py.
class MeloLogo extends StatelessWidget {
  const MeloLogo({super.key, this.width = AppSizes.launchLogo});

  static const asset = 'assets/branding/melo-logo.png';

  /// Width over height of the logo's view box, so the space is reserved
  /// before the image has decoded.
  static const aspectRatio = 990 / 525;

  final double width;

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Image.asset(
          asset,
          cacheWidth: (width * pixelRatio).round(),
          filterQuality: FilterQuality.medium,
          semanticLabel: context.l10n.appTitle,
        ),
      ),
    );
  }
}
