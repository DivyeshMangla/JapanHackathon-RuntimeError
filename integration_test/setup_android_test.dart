import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:melo/core/setup_state.dart';
import 'package:melo/core/setup_strings.dart';
import 'package:melo/data/setup_repository.dart';
import 'package:melo/features/setup/setup_app.dart';
import 'package:melo/features/setup/setup_service.dart';
import 'package:melo/transport/qr_codec.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android Keystore, PIN, key generation and cold-session routing',
    (tester) async {
      final directory = await getApplicationDocumentsDirectory();
      // Fail BEFORE any write unless Gradle used the isolated test application ID.
      expect(directory.path, contains('/com.melo.app.setupcheck/'));
      const secrets = AndroidSecretStore();
      final repository = await EncryptedSetupRepository.open(secrets);
      final service = SetupService(repository, secrets);
      await service.load();
      if (service.state.stage != SetupStage.unset) {
        await service.resetTherapist('DELETE');
      } else {
        await service.chooseRole(DeviceRole.therapist);
      }
      await SetupStrings.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [setupServiceProvider.overrideWithValue(service)],
          child: const SetupApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Therapist signup'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).at(0),
        'Synthetic device test',
      );
      await tester.enterText(find.byType(TextField).at(1), 'Test clinic');
      await tester.enterText(find.byType(TextField).at(2), 'TEST');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Set therapist PIN'), findsOneWidget);
      // Exercise production PBKDF2 and secure storage; tests never lower its cost.
      await service.setPin('123456', '123456', false);
      await service.generateKeys();
      await tester.pumpAndSettle();
      expect(find.text('My patients'), findsOneWidget);
      final public = service.joinEnvelope();
      expect((await QrCodec.frames(public)).length, 1);
      final id = service.id;
      await service
          .load(); // New-session semantics with real persistent storage.
      await tester.pumpAndSettle();
      expect(find.text('Therapist PIN'), findsOneWidget);
      expect(service.id, id);
      expect(await service.unlock('123456'), true);
      await tester.pumpAndSettle();
      expect(find.text('My patients'), findsOneWidget);
      await service.resetTherapist('DELETE');
      await tester.pumpAndSettle();
      expect(find.text('Therapist signup'), findsOneWidget);
      expect(await secrets.read('signing'), null);
      await tester.pumpWidget(const SizedBox());
      await repository.box.close();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
