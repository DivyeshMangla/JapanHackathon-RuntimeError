import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/app_failure.dart';
import 'package:melo/core/network/backend_client.dart';
import 'package:melo/features/auth/data/backend_auth_repository.dart';
import 'package:melo/features/auth/data/backend_user_repository.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/parent/data/backend_family_repository.dart';
import 'package:melo/features/parent/domain/consent.dart';
import 'package:melo/features/recordings/data/backend_recording_repository.dart';
import 'package:melo/features/recordings/domain/recording.dart';
import 'package:melo/features/settings/data/backend_settings_repository.dart';
import 'package:melo/features/settings/domain/study_settings.dart';
import 'package:melo/features/usage/data/backend_usage_log_repository.dart';
import 'package:melo/features/usage/domain/usage_event.dart';

import 'support/synthetic_voice.dart';

/// A 1 by 1 PNG, enough for the service's signature check.
final _signature = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=',
);

class _MemoryTokens implements SessionTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String? token) async => this.token = token;
}

/// One signed-in account talking to the real service.
class _Session {
  _Session(String baseUrl)
    : client = BackendClient(baseUrl: baseUrl, tokens: _MemoryTokens()) {
    users = BackendUserRepository(client);
    auth = BackendAuthRepository(client, users);
  }

  final BackendClient client;
  late final BackendUserRepository users;
  late final BackendAuthRepository auth;
}

/// Starts the Node service on a temporary database seeded with the demo
/// accounts. The tests that need it are skipped where Node is not installed.
Future<({String baseUrl, Future<void> Function() stop})> _startService() async {
  final root = Directory.current.path;
  final dataDir = await Directory.systemTemp.createTemp('melo-service-');
  final env = {'DATA_DIR': dataDir.path};
  final seed = await Process.run('node', [
    '$root/backend/src/seed.mjs',
  ], environment: env);
  if (seed.exitCode != 0) throw StateError('Seeding failed: ${seed.stderr}');

  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  final process = await Process.start(
    'node',
    ['$root/backend/src/server.mjs'],
    environment: {...env, 'PORT': '$port', 'HOST': '127.0.0.1'},
  );
  final ready = Completer<void>();
  process.stdout.transform(utf8.decoder).listen((line) {
    if (!ready.isCompleted && line.contains('Melo admin')) {
      ready.complete();
    }
  }, onError: (_) {});
  unawaited(process.stderr.drain<void>());
  await ready.future.timeout(const Duration(seconds: 20));
  return (
    baseUrl: 'http://127.0.0.1:$port',
    stop: () async {
      process.kill();
      await process.exitCode;
      await dataDir.delete(recursive: true);
    },
  );
}

Future<bool> _nodeAvailable() async {
  try {
    return (await Process.run('node', ['--version'])).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  late String baseUrl;
  late Future<void> Function() stop;
  var nodeMissing = false;

  setUpAll(() async {
    if (!await _nodeAvailable()) {
      nodeMissing = true;
      return;
    }
    final service = await _startService();
    baseUrl = service.baseUrl;
    stop = service.stop;
  });

  tearDownAll(() async {
    if (!nodeMissing) await stop();
  });

  test('the app repositories work against the real care service', () async {
    if (nodeMissing) {
      markTestSkipped('Node is not installed');
      return;
    }
    const demoPassword = 'VoiceDemo!2026';

    // A wrong password is an ordinary outcome, not a failure.
    final stranger = _Session(baseUrl);
    expect(
      await stranger.auth.signIn(email: 'admin@melo.test', password: 'nope'),
      isNull,
    );

    // The administrator sets the probe schedule.
    final admin = _Session(baseUrl);
    final adminUser = await admin.auth.signIn(
      email: 'admin@melo.test',
      password: demoPassword,
    );
    expect(adminUser?.role, UserRole.admin);
    await BackendSettingsRepository(
      admin.client,
    ).save(const StudySettings(probeIntervalDays: 14));

    // Patients carry sequential participant codes.
    final patients = await admin.users.listByRole(UserRole.patient);
    expect(patients.first.participantCode, 'P001');

    // The therapist reads their caseload, and another therapist's patient is
    // off limits.
    final therapist = _Session(baseUrl);
    final therapistUser = (await therapist.auth.signIn(
      email: 'meera@melo.test',
      password: demoPassword,
    ))!;
    final caseload = await therapist.users.patientsOf(therapistUser.id);
    expect(caseload, isNotEmpty);
    expect(
      (await BackendSettingsRepository(
        therapist.client,
      ).load()).probeIntervalDays,
      14,
    );
    final other = patients.firstWhere((p) => p.therapistId != therapistUser.id);
    await expectLater(
      BackendUsageLogRepository(therapist.client).forPatient(other.id),
      throwsA(isA<NetworkFailure>()),
    );

    // The demo parent hands the phone to their child in child mode. The
    // child logs and records, and only the parent's password leaves.
    final phone = _Session(baseUrl);
    final parentUser = (await phone.auth.signIn(
      email: 'parent@melo.test',
      password: demoPassword,
    ))!;
    final patient = (await phone.users.listByRole(
      UserRole.patient,
    )).singleWhere((child) => child.parentId == parentUser.id);
    final child = await phone.auth.startChildMode(patient.id);
    expect(child.id, patient.id);
    expect(child.email, isEmpty);
    expect((await phone.auth.restoreSession())?.id, patient.id);

    await BackendUsageLogRepository(phone.client).append(
      UsageEvent(
        at: DateTime.now(),
        patientId: patient.id,
        action: UsageAction.signIn,
      ),
    );
    final wav = File('${Directory.systemTemp.path}/melo-integration.wav');
    await wav.writeAsBytes(syntheticVoiceWav(seconds: 0.3, pitchHz: 200));
    final recording = Recording(
      id: 'rec-integration',
      patientId: patient.id,
      kind: RecordingKind.practice,
      task: RecordingTask.sustainedPhonation,
      type: RecordingType.homePractice,
      durationSec: 0.3,
      createdAt: DateTime.now(),
    );
    await BackendRecordingRepository(
      phone.client,
    ).save(recording, wavPath: wav.path);
    await wav.delete();

    expect(await phone.auth.endChildMode('not the password'), isNull);
    expect((await phone.auth.restoreSession())?.id, patient.id);
    expect((await phone.auth.endChildMode(demoPassword))?.id, parentUser.id);
    expect((await phone.auth.restoreSession())?.id, parentUser.id);

    // The therapist now sees the child's records and can play the audio.
    expect(
      (await BackendUsageLogRepository(
        therapist.client,
      ).forPatient(patient.id)).single.action,
      UsageAction.signIn,
    );
    final recordings = BackendRecordingRepository(therapist.client);
    expect((await recordings.forPatient(patient.id)).single.id, recording.id);
    final audio = await recordings.audio(recording.id);
    expect(ascii.decode(audio.sublist(0, 4)), 'RIFF');

    // A parent joins with the therapist's code and adds a child, signing
    // consent with the child's account.
    final family = _Session(baseUrl);
    final parent = await family.auth.registerParent(
      name: 'New Parent',
      email: 'new.parent@melo.test',
      password: 'a-long-enough-password',
      therapistCode: therapistUser.linkCode!,
    );
    expect(parent.role, UserRole.parent);
    expect(parent.therapistId, therapistUser.id);
    final familyRepository = BackendFamilyRepository(family.client);
    final form = await familyRepository.consentForm();
    final added = await familyRepository.addChild(
      childName: 'Kavya',
      version: form.version,
      signerName: 'New Parent',
      agreed: ConsentStatement.values.toSet(),
      signaturePng: _signature,
    );
    expect(added.parentId, parent.id);
    expect(added.participantCode, isNot(patients.last.participantCode));
    expect((await familyRepository.consentFor(added.id))?.analysisAgreed, true);
    expect((await family.users.listByRole(UserRole.patient)).map((c) => c.id), [
      added.id,
    ]);

    // The administrator adds a parent, and an email can be used only once.
    await admin.users.create(
      role: UserRole.parent,
      name: 'Created Parent',
      email: 'created.parent@melo.test',
      password: 'a-long-enough-password',
      therapistId: therapistUser.id,
    );
    await expectLater(
      admin.users.create(
        role: UserRole.parent,
        name: 'Duplicate',
        email: 'created.parent@melo.test',
        password: 'a-long-enough-password',
        therapistId: therapistUser.id,
      ),
      throwsA(
        isA<InvalidInputFailure>().having(
          (f) => f.problem,
          'problem',
          InputProblem.emailTaken,
        ),
      ),
    );

    // Signing out ends the session.
    await family.auth.signOut();
    expect(await family.auth.restoreSession(), isNull);
  });
}
