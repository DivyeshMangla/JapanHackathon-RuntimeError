import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/setup_state.dart';
import 'package:melo/features/setup/setup_service.dart';
import 'package:melo/transport/sync_envelope.dart';
import 'package:melo/transport/sync_transport.dart';

import 'setup_test_helpers.dart';

void main() {
  test(
    'two isolated devices: join → signed consent → countersign → forms → plan → active',
    () async {
      final therapist = device(), patient = device(), other = device();
      final transport = FakeTransport();
      await therapistReady(therapist);
      await therapistReady(other);
      await patient.load();
      await patient.chooseRole(DeviceRole.patient);
      await transport.send(therapist.joinEnvelope());
      await patient.join((await transport.receive())!);
      expect(patient.therapist!.id, therapist.id);
      expect(
        therapist.patients,
        isEmpty,
      ); // Public join profile grants nothing.
      await patient.selectLanguage('pa');
      await patient.readInformation();
      await expectLater(patient.agree(), throwsSetupFailure);
      await patient.saveChecks({
        for (final item in ConsentItem.values) item: item.isRequired,
      });
      await patient.agree();
      await patient.signConsent(signaturePng);
      final consent = await patient.consentEnvelope();
      await transport.send(consent);
      await patient.markConsentSent();
      await patient.load(); // Resume exactly at awaitingPlan, no PIN.
      expect(patient.state.stage, SetupStage.awaitingPlan);
      await expectLater(other.importConsent(consent), throwsSetupFailure);
      expect(other.patients, isEmpty);
      await therapist.importConsent((await transport.receive())!);
      await expectLater(
        therapist.saveForms(patient.id, syntheticForms),
        throwsSetupFailure,
      );
      await expectLater(
        therapist.approve(patient.id, false),
        throwsSetupFailure,
      );
      await therapist.approve(patient.id, true);
      await therapist.saveForms(patient.id, syntheticForms);
      await therapist.prescribe(patient.id, mockExercises.take(3).toList(), 5);
      await therapist.importConsent(
        consent,
      ); // Duplicate does not downgrade approval.
      expect(
        therapist.patient(patient.id)!.status,
        SetupPatientStatus.planReady,
      );
      final plan = therapist.planEnvelope(patient.id);
      expect(plan.encode(), isNot(contains('Synthetic')));
      final wrongRecipient = SyncEnvelope.decode(
        jsonEncode({...plan.toJson(), 'recipientId': 'other-patient'}),
      );
      await expectLater(patient.importPlan(wrongRecipient), throwsSetupFailure);
      final modified =
          jsonDecode(utf8.decode(base64Decode(plan.ciphertext)))
              as Map<String, dynamic>;
      (modified['record'] as Map<String, dynamic>)['dose'] = 99;
      final tampered = SyncEnvelope.decode(
        jsonEncode({
          ...plan.toJson(),
          'ciphertext': base64Encode(utf8.encode(jsonEncode(modified))),
        }),
      );
      await expectLater(patient.importPlan(tampered), throwsSetupFailure);
      await transport.send(plan);
      await patient.importPlan((await transport.receive())!);
      expect(patient.state.stage, SetupStage.orientation);
      await patient.finishOrientation();
      await expectLater(patient.finishBaseline(), throwsSetupFailure);
      for (var i = 0; i < 3; i++) {
        await patient.completeBaseline(i);
      }
      await patient.finishBaseline();
      await patient.load();
      expect(patient.state.route(unlocked: false), '/active');
      expect(other.patients, isEmpty);
    },
  );

  test('a therapist can approve consent straight after importing it', () async {
    final therapist = device(), patient = device();
    await therapistReady(therapist);
    await patientConsent(patient, therapist);
    await therapist.importConsent(await patient.consentEnvelope());
    await therapist.approve(patient.id, true);
    expect(therapist.patient(patient.id)!.status, SetupPatientStatus.approved);
  });
}
