import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/setup_state.dart';
import 'package:melo/crypto/pin_service.dart';
import 'package:melo/data/setup_repository.dart';
import 'package:melo/features/setup/setup_app.dart';
import 'package:melo/features/setup/setup_service.dart';

import 'setup_test_helpers.dart';

void main() {
  test('all stages resume and route guards prevent skipping setup', () async {
    for (final stage in SetupStage.values) {
      final repository = MemorySetupRepository();
      await repository.save({'stage': stage.name});
      final service = SetupService(repository, MemorySecretStore());
      await service.load();
      expect(service.state.stage, stage);
      expect(service.unlocked, false);
      expect(
        setupRedirect(service, '/therapist/forms/unknown'),
        stage == SetupStage.ready ? '/unlock' : '/${stage.name}',
      );
      expect(
        setupRedirect(service, service.state.route(unlocked: false)),
        null,
      );
    }
    expect(
      const SetupState(SetupStage.active).route(unlocked: false),
      '/active',
    );
    expect(
      () => const SetupState(SetupStage.needsJoin).advance(SetupStage.active),
      throwsStateError,
    );
    expect(
      () => const SetupState(SetupStage.ready).advance(SetupStage.needsSignup),
      throwsStateError,
    );
    expect(
      const SetupState(SetupStage.unset).advance(SetupStage.needsSignup).role,
      DeviceRole.therapist,
    );
  });

  test(
    'PIN has independent salts, no plaintext, validation and restart-safe escalating lockout',
    () async {
      final secrets = MemorySecretStore();
      var now = DateTime.utc(2026);
      var pin = PinService(secrets, now: () => now, iterations: 10);
      await expectLater(pin.set('12'), throwsSetupFailure);
      await expectLater(pin.set('12abcd'), throwsSetupFailure);
      await pin.set('1234');
      final first =
          jsonDecode((await secrets.read('pin'))!) as Map<String, dynamic>;
      await pin.set('1234');
      final second =
          jsonDecode((await secrets.read('pin'))!) as Map<String, dynamic>;
      expect(first['salt'], isNot(second['salt']));
      expect(first['hash'], isNot(second['hash']));
      expect(second.values, isNot(contains('1234')));
      for (var i = 0; i < 5; i++) {
        expect(await pin.verify('0000'), false);
      }
      expect(await pin.remaining(), const Duration(seconds: 30));
      pin = PinService(secrets, now: () => now, iterations: 10);
      expect(await pin.verify('1234'), false);
      now = now.add(const Duration(seconds: 30));
      for (var i = 0; i < 5; i++) {
        await pin.verify('0000');
      }
      expect(await pin.remaining(), const Duration(seconds: 60));
      now = now.add(const Duration(seconds: 60));
      expect(await pin.verify('1234'), true);
      expect(await pin.remaining(), Duration.zero);
    },
  );

  test(
    'therapist restart locks, wipe removes keys and all patient state',
    () async {
      final therapist = device();
      await therapistReady(therapist);
      final patient = device();
      await patientConsent(patient, therapist);
      await therapist.importConsent(await patient.consentEnvelope());
      final restart = SetupService(
        therapist.repository,
        therapist.secrets,
        pin: therapist.pin,
      );
      await restart.load();
      expect(restart.unlocked, false);
      expect(() => restart.joinEnvelope(), throwsSetupFailure);
      await expectLater(restart.resetTherapist('delete'), throwsSetupFailure);
      expect(restart.patients, isNotEmpty);
      await restart.resetTherapist('DELETE');
      expect(restart.state.stage, SetupStage.needsSignup);
      expect(restart.patients, isEmpty);
      expect(await restart.secrets.read('signing'), null);
      expect(await restart.secrets.read('encryption'), null);
      expect(await restart.secrets.read('pin'), null);
    },
  );

  test(
    'interrupted wipe resumes instead of opening previous records',
    () async {
      final service = device();
      await therapistReady(service);
      await service.secrets.write('resetPending', 'true');
      await service.load();
      expect(service.state.stage, SetupStage.needsSignup);
      expect(await service.secrets.read('signing'), null);
    },
  );
}
