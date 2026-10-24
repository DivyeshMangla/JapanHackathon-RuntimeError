import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/logging/app_logger.dart';
import 'core/network/backend_client.dart';
import 'core/network/server_address.dart';
import 'core/storage/local_database.dart';
import 'features/recordings/data/recording_repository_providers.dart';
import 'shared/widgets/launch_view.dart';
import 'shared/widgets/startup_failure_view.dart';

/// Run with `--dart-define=API_BASE_URL=https://...`. The default reaches a
/// service on the host machine from an Android emulator.
const _serverAddress = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8787',
);

/// Opens device storage, points the app at the care service, then starts it.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LaunchApp());
  try {
    final database = await LocalDatabase.open();
    final container = ProviderContainer(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        backendClientProvider.overrideWithValue(
          BackendClient(
            baseUrl: validatedServerOrigin(_serverAddress),
            tokens: const SecureSessionTokenStore(),
          ),
        ),
      ],
    );
    await container.read(playbackFilesProvider).clearAll();
    runApp(
      UncontrolledProviderScope(container: container, child: const MeloApp()),
    );
  } catch (failure, stack) {
    AppLogger.error('The app could not start', failure, stack);
    runApp(const StartupFailureApp());
  }
}
