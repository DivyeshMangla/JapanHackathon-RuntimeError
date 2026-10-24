import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/page_list.dart';
import 'microphone_panel.dart';
import 'motion_panels.dart';

/// Developer screen showing the live sensors the recording quality checks
/// rely on (research doc sections 3 and 4.3), styled as an instrument
/// readout. Reachable from the login screen in debug and profile builds only.
class SensorCheckScreen extends StatelessWidget {
  const SensorCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.diagnostics,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.sensorCheckTitle.toUpperCase()),
          ),
          body: PageList(
            children: [
              Text(
                context.l10n.sensorCheckNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              const MicrophonePanel(),
              const SizedBox(height: AppSpacing.md),
              const MotionPanel(),
              const SizedBox(height: AppSpacing.md),
              const OrientationPanel(),
              const SizedBox(height: AppSpacing.md),
              const ProximityPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
