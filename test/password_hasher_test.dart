import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/security/password_hasher.dart';

void main() {
  const hasher = PasswordHasher(logRounds: 4);

  test('verifies the original password and rejects others', () async {
    final hash = await hasher.hash('PatientDemo2026');

    expect(hash, isNot(contains('PatientDemo2026')));
    expect(await hasher.verify('PatientDemo2026', hash), isTrue);
    expect(await hasher.verify('patientdemo2026', hash), isFalse);
  });

  test('rejects passwords beyond the bcrypt byte limit', () async {
    final hash = await hasher.hash('short');
    expect(await hasher.verify('x' * 73, hash), isFalse);
  });
}
