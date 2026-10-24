import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:melo/data/setup_repository.dart';
import 'package:melo/features/connected/data/connected_service.dart';
import 'package:melo/features/connected/presentation/connected_app.dart';

class _MemorySecrets implements SecretStore {
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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('connected-screens-');
    Hive.init(directory.path);
    box = await Hive.openBox<String>(
      'connected_screens',
      encryptionCipher: HiveAesCipher(List.generate(32, (i) => i)),
    );
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  testWidgets('sign-in checks fields on the page before calling the server', (
    tester,
  ) async {
    final service = ConnectedService(
      'http://127.0.0.1:9',
      box,
      _MemorySecrets(),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(ConnectedApp(service: service));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('This field is required.'), findsOneWidget);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Therapist'));
    await tester.pumpAndSettle();
    expect(find.text('Clinic'), findsOneWidget);
    expect(find.text('Registration number'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
