import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/app_failure.dart';
import 'package:melo/core/network/backend_client.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/features/auth/data/backend_auth_repository.dart';
import 'package:melo/features/auth/data/backend_user_repository.dart';
import 'package:melo/features/auth/domain/user.dart';
import 'package:melo/features/exercises/data/backend_exercise_repositories.dart';
import 'package:melo/features/exercises/domain/completion.dart';
import 'package:melo/features/exercises/domain/schedule.dart';
import 'package:melo/features/exercises/domain/voice_use_entry.dart';
import 'package:melo/features/recordings/data/backend_recording_repository.dart';
import 'package:melo/features/recordings/domain/recording.dart';
import 'package:melo/features/settings/data/backend_settings_repository.dart';
import 'package:melo/features/settings/domain/study_settings.dart';
import 'package:melo/features/usage/data/backend_usage_log_repository.dart';
import 'package:melo/features/usage/domain/usage_event.dart';

import 'support/exercise_fixtures.dart';
import 'support/synthetic_voice.dart';

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

    // The administrator publishes an approved exercise.
    final admin = _Session(baseUrl);
    final adminUser = await admin.auth.signIn(
      email: 'admin@melo.test',
      password: demoPassword,
    );
    expect(adminUser?.role, UserRole.admin);
    final library = BackendExerciseRepository(admin.client);
    expect(
      (await library.all()).map((e) => e.id),
      isNot(contains(plainExercise.id)),
    );
    final exercise = plainExercise.approve(
      by: adminUser!.id,
      at: DateTime(2026, 5, 1),
    );
    await library.save(exercise);
    expect((await library.byId(exercise.id))?.title, plainExercise.title);
    await BackendSettingsRepository(
      admin.client,
    ).save(const StudySettings(adherenceThreshold: 0.7));

    // Patients carry sequential participant codes.
    final patients = await admin.users.listByRole(UserRole.patient);
    expect(patients.first.participantCode, 'P001');

    // The assigned therapist can read their patient and assign the exercise.
    final therapist = _Session(baseUrl);
    final therapistUser = (await therapist.auth.signIn(
      email: 'meera@melo.test',
      password: demoPassword,
    ))!;
    final caseload = await therapist.users.patientsOf(therapistUser.id);
    expect(caseload, isNotEmpty);
    final patient = caseload.first;
    expect(
      (await BackendSettingsRepository(
        therapist.client,
      ).load()).adherenceThreshold,
      0.7,
    );
    final schedule = Schedule(
      id: 'sched-integration',
      patientId: patient.id,
      exerciseId: exercise.id,
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      effectiveFrom: dateOnly(DateTime.now()),
      assignedBy: therapistUser.id,
    );
    await BackendScheduleRepository(therapist.client).save(schedule);

    // Another therapist's patient is off limits.
    final other = caseload.length < patients.length
        ? patients.firstWhere((p) => p.therapistId != therapistUser.id)
        : null;
    if (other != null) {
      await expectLater(
        BackendScheduleRepository(therapist.client).forPatient(other.id),
        throwsA(isA<NetworkFailure>()),
      );
    }

    // The child's device opens with the demo parent's code and the child's
    // name, then sees the assignment, marks it done, logs and records.
    final patientSession = _Session(baseUrl);
    final signedIn = await patientSession.auth.setUpChild(
      parentCode: 'parent',
      childName: patient.name,
    );
    expect(signedIn.id, patient.id);
    expect(signedIn.email, isEmpty);
    final assignments = await BackendScheduleRepository(
      patientSession.client,
    ).forPatient(patient.id);
    expect(assignments.map((a) => a.exerciseId), contains(exercise.id));

    final today = dateOnly(DateTime.now());
    final completions = BackendCompletionRepository(patientSession.client);
    final done = Completion(
      id: 'done-integration',
      patientId: patient.id,
      exerciseId: exercise.id,
      day: today,
      completedAt: DateTime.now(),
    );
    await completions.add(done);
    final listed = await completions.forPatient(
      patient.id,
      from: today,
      to: today,
    );
    expect(listed.single.id, done.id);
    expect(listed.single.day, today);
    await completions.delete(patientId: patient.id, id: done.id);
    expect(
      await completions.forPatient(patient.id, from: today, to: today),
      isEmpty,
    );

    await BackendVoiceDiaryRepository(patientSession.client).save(
      VoiceUseEntry(
        id: 'diary-integration',
        patientId: patient.id,
        day: today,
        loggedAt: DateTime.now(),
        speakingTime: SpeakingTime.oneToTwoHours,
        fatigue: 2,
        situations: const {VoiceSituation.phoneCalls},
      ),
    );
    await BackendUsageLogRepository(patientSession.client).append(
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
      patientSession.client,
    ).save(recording, wavPath: wav.path);
    await wav.delete();

    // The therapist now sees the patient's records and can play the audio.
    expect(
      (await BackendVoiceDiaryRepository(
        therapist.client,
      ).forPatient(patient.id)).single.fatigue,
      2,
    );
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

    // A parent joins with the therapist's code, and their code sets up a
    // new child on the same caseload.
    final family = _Session(baseUrl);
    final parent = await family.auth.registerParent(
      name: 'New Parent',
      email: 'new.parent@melo.test',
      password: 'a-long-enough-password',
      therapistCode: therapistUser.linkCode!,
    );
    expect(parent.role, UserRole.parent);
    expect(parent.therapistId, therapistUser.id);
    final childDevice = _Session(baseUrl);
    final child = await childDevice.auth.setUpChild(
      parentCode: parent.linkCode!,
      childName: 'Kavya',
    );
    expect(child.parentId, parent.id);
    expect(child.participantCode, isNot(patients.last.participantCode));
    expect((await family.users.listByRole(UserRole.patient)).map((c) => c.id), [
      child.id,
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
    await patientSession.auth.signOut();
    expect(await patientSession.auth.restoreSession(), isNull);
  });
}
