import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/errors/app_failure.dart';
import 'package:melo/core/errors/guard.dart';

void main() {
  test('unexpected errors become the requested typed failure', () async {
    const cause = FileSystemException('disk full');
    await expectLater(
      guardStorage<void>(() => throw cause),
      throwsA(
        isA<StorageFailure>().having((f) => f.cause, 'cause', same(cause)),
      ),
    );
  });

  test('typed failures pass through unchanged', () async {
    const failure = InvalidInputFailure(InputProblem.emailTaken);
    await expectLater(
      guard<void>(() => throw failure, ExportFailure.new),
      throwsA(same(failure)),
    );
  });

  test('successful results are returned as is', () async {
    expect(await guardStorage(() => 42), 42);
  });
}
