import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:melo/core/errors/connected_failure.dart';
import 'package:melo/data/setup_repository.dart';
import 'package:melo/features/connected/data/connected_service.dart';
import 'package:melo/features/connected/domain/connected_models.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> clear() async => values.clear();
}

void main() {
  late Directory directory;
  late Box<String> box;
  late HttpServer server;
  late MemorySecrets secrets;
  late ConnectedService service;
  late Map<String, Map<String, dynamic>> accounts;
  late List<Map<String, dynamic>> received;
  var rejectSync = false;
  var rejectSession = false;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'connected-service-test-',
    );
    Hive.init(directory.path);
    box = await Hive.openBox<String>(
      'connected_test',
      encryptionCipher: HiveAesCipher(List.generate(32, (i) => i)),
    );
    secrets = MemorySecrets();
    rejectSync = false;
    rejectSession = false;
    received = [];
    accounts = {
      'patient-a': {
        'id': 'patient-a',
        'name': 'Patient A',
        'email': 'a@example.test',
        'role': 'patient',
      },
      'patient-b': {
        'id': 'patient-b',
        'name': 'Patient B',
        'email': 'b@example.test',
        'role': 'patient',
      },
      'therapist': {
        'id': 'therapist',
        'name': 'Therapist',
        'email': 't@example.test',
        'role': 'therapist',
      },
    };
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final content = await utf8.decoder.bind(request).join();
      final body = content.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(content) as Map<String, dynamic>;
      final path = request.uri.path;
      final owner = (request.headers.value('Authorization') ?? '').replaceFirst(
        'Bearer ',
        '',
      );
      Object response = {};
      if (path == '/api/config') {
        response = {'exercises': [], 'consentVersion': 'test'};
      } else if (path == '/api/auth/login') {
        final user = accounts.values.firstWhere(
          (u) => u['email'] == body['email'],
        );
        response = {'user': user, 'token': user['id']};
      } else if (path == '/api/auth/logout') {
        response = {'ok': true};
      } else if (path == '/api/auth/me') {
        if (rejectSession) {
          request.response.statusCode = 401;
          response = {'error': 'Session revoked'};
        } else {
          response = {'user': accounts[owner]};
        }
      } else if (path.endsWith('/progress') ||
          path.endsWith('/recordings') ||
          path.endsWith('/motor-submissions')) {
        received.add({'owner': owner, 'path': path, 'body': body});
        if (rejectSync) {
          request.response.statusCode = 503;
          response = {'error': 'Retry later'};
        } else {
          response = {'ok': true};
        }
      } else if (path == '/api/patients') {
        response = {'patients': []};
      } else {
        response = {
          'patient': accounts[owner],
          'plan': null,
          'consent': null,
          'progress': [],
          'recordings': [],
        };
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
    service = ConnectedService('http://127.0.0.1:${server.port}', box, secrets);
  });
  tearDown(() async {
    service.dispose();
    await server.close(force: true);
    await box.close();
    await directory.delete(recursive: true);
  });

  test(
    'motor photo failures surface and retry preserves original bytes and ID',
    () async {
      await service.signIn('a@example.test', 'example-password');
      Future<void> send() => service.submitMotorPhoto(
        submissionId: 'photo-1',
        planId: 'plan-a',
        exerciseId: 'motor-lines',
        photo: [1, 2, 3, 4],
        practiceDay: '2026-10-24',
      );
      rejectSync = true;
      await expectLater(send(), throwsA(isA<ConnectedFailure>()));
      expect(service.outbox, isEmpty);
      rejectSync = false;
      await send();
      expect(received, hasLength(2));
      expect(received.first['body'], received.last['body']);
      expect((received.last['body'] as Map)['photo'], 'AQIDBA==');
      expect(
        received.last['path'],
        '/api/patients/patient-a/motor-submissions',
      );
    },
  );

  test(
    'failed progress upload survives restart and retries the same event ID',
    () async {
      await service.signIn('a@example.test', 'example-password');
      rejectSync = true;
      await service.savePractice(
        planId: 'plan-a',
        exerciseId: 'humming',
        minutes: 5,
      );
      expect(service.outbox, hasLength(1));
      final eventId = service.outbox.single.id;
      final restored = ConnectedService(service.baseUrl, box, secrets);
      await restored.restore();
      expect(restored.outbox, hasLength(1));
      rejectSync = false;
      await restored.sync();
      expect(restored.outbox, isEmpty);
      expect(received.map((r) => (r['body'] as Map)['id']).toSet(), {eventId});
      restored.dispose();
    },
  );

  test('account queues are isolated and retained across logout', () async {
    rejectSync = true;
    await service.signIn('a@example.test', 'example-password');
    await service.savePractice(
      planId: 'plan-a',
      exerciseId: 'humming',
      minutes: 4,
    );
    await service.signOut();
    expect(service.user, isNull);
    expect(service.outbox, isEmpty);
    await service.signIn('b@example.test', 'example-password');
    expect(service.outbox, isEmpty);
    await service.savePractice(
      planId: 'plan-b',
      exerciseId: 'reading',
      minutes: 6,
    );
    expect(
      received.every(
        (r) => r['path'] == '/api/patients/${r['owner']}/progress',
      ),
      isTrue,
    );
    await service.signOut();
    await service.signIn('a@example.test', 'example-password');
    expect(service.outbox, hasLength(1));
    expect(service.outbox.single.planId, 'plan-a');
  });

  test(
    'recording bytes are durably queued before upload and removed after success',
    () async {
      await service.signIn('a@example.test', 'example-password');
      rejectSync = true;
      await service.saveRecording(
        planId: 'plan',
        exerciseId: 'humming',
        audio: [1, 2, 3, 4],
        seconds: 5,
      );
      expect(service.outbox.single.kind, OutboxKind.recordings);
      expect((received.last['body'] as Map)['audio'], 'AQIDBA==');
      rejectSync = false;
      await service.sync();
      expect(service.outbox, isEmpty);
    },
  );

  test(
    'restored therapists remain locked and revoked sessions are cleared',
    () async {
      await service.signIn('t@example.test', 'example-password');
      expect(service.locked, isTrue);
      expect(service.needsPin, isTrue);
      final restored = ConnectedService(service.baseUrl, box, secrets);
      await restored.restore();
      expect(restored.locked, isTrue);
      restored.dispose();
      rejectSession = true;
      final revoked = ConnectedService(service.baseUrl, box, secrets);
      await revoked.restore();
      expect(revoked.user, isNull);
      expect(box.get('user'), isNull);
      revoked.dispose();
    },
  );

  test(
    'biometrics cannot bypass a PIN lockout and cancellation stays locked',
    () async {
      await secrets.write('therapist:biometrics', 'true');
      await service.signIn('t@example.test', 'example-password');
      expect(service.biometricsEnabled, isTrue);
      await secrets.write(
        'therapist:pin',
        jsonEncode({'until': DateTime.now().millisecondsSinceEpoch + 30000}),
      );
      var requested = false;
      await expectLater(
        service.unlockBiometric(() async {
          requested = true;
          return true;
        }),
        throwsA(
          isA<ConnectedFailure>().having(
            (failure) => failure.reason,
            'reason',
            ConnectedFailureReason.pinLocked,
          ),
        ),
      );
      expect(requested, isFalse);
      expect(service.locked, isTrue);
      await secrets.write('therapist:pin', jsonEncode({'until': 0}));
      await service.unlockBiometric(() async => false);
      expect(service.locked, isTrue);
      await service.unlockBiometric(() async => true);
      expect(service.locked, isFalse);
    },
  );
}
