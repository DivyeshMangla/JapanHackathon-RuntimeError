import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/setup_failure.dart';
import 'package:melo/core/setup_state.dart';
import 'package:melo/crypto/pin_service.dart';
import 'package:melo/data/setup_repository.dart';
import 'package:melo/features/setup/setup_service.dart';

final signaturePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aP5sAAAAASUVORK5CYII=',
);

final throwsSetupFailure = throwsA(isA<SetupFailure>());

const syntheticForms = ParticipantForms(
  age: 25,
  demographic: 'Synthetic only',
  clinical: 'Synthetic only',
);

SetupService device() {
  final secrets = MemorySecretStore();
  return SetupService(
    MemorySetupRepository(),
    secrets,
    pin: PinService(secrets, iterations: 10),
  );
}

Future<void> therapistReady(SetupService therapist) async {
  await therapist.load();
  await therapist.chooseRole(DeviceRole.therapist);
  await therapist.signup('Test therapist', 'Test clinic', 'SELF-DECLARED');
  await therapist.setPin('123456', '123456', false);
  await therapist.generateKeys();
}

Future<void> patientConsent(
  SetupService patient,
  SetupService therapist,
) async {
  await patient.load();
  await patient.chooseRole(DeviceRole.patient);
  await patient.join(therapist.joinEnvelope());
  await patient.selectLanguage('hi');
  await patient.readInformation();
  await patient.saveChecks({
    for (final item in ConsentItem.values) item: item.isRequired,
  });
  await patient.agree();
  await patient.signConsent(signaturePng);
}
