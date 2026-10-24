import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logging/app_logger.dart';
import 'core/setup_strings.dart';
import 'data/setup_repository.dart';
import 'features/setup/presentation/startup_message.dart';
import 'features/setup/setup_app.dart';
import 'features/setup/setup_service.dart';
import 'shared/widgets/launch_view.dart';
import 'transport/file_transport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LaunchApp());
  await SetupStrings.load();
  if (!Platform.isAndroid) {
    runApp(StartupMessage(SetupStrings.text('en', 'androidOnly')));
    return;
  }
  try {
    const secrets = AndroidSecretStore();
    final repository = await EncryptedSetupRepository.open(secrets);
    await FileTransport.clearCachedTransfers();
    final service = SetupService(
      repository,
      secrets,
      purgeTransfers: FileTransport.clearCachedTransfers,
    );
    await service.load();
    runApp(
      ProviderScope(
        overrides: [setupServiceProvider.overrideWithValue(service)],
        child: const SetupApp(),
      ),
    );
  } catch (failure, stack) {
    AppLogger.error('Secure setup storage failed to open', failure, stack);
    runApp(StartupMessage(SetupStrings.text('en', 'storageFailed')));
  }
}
