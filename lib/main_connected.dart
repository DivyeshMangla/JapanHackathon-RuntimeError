import 'package:flutter/material.dart';

import 'core/logging/app_logger.dart';
import 'features/connected/data/connected_service.dart';
import 'features/connected/presentation/connected_app.dart';
import 'shared/widgets/launch_view.dart';

/// Run with --flavor connected -t lib/main_connected.dart and API_BASE_URL.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LaunchApp());
  const url = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8787',
  );
  try {
    final service = await ConnectedService.open(url);
    runApp(ConnectedApp(service: service));
  } catch (failure, stack) {
    AppLogger.error('Connected workspace failed to open', failure, stack);
    runApp(const ConnectedStartupFailure());
  }
}
