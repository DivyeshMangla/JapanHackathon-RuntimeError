import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../core/errors/setup_failure.dart';
import '../data/setup_repository.dart';

class PinService {
  PinService(this.secrets, {DateTime Function()? now, this.iterations = 600000})
    : now = now ?? DateTime.now;
  final SecretStore secrets;
  final DateTime Function() now;
  final int iterations;
  bool _busy = false;
  Future<Map<String, dynamic>> _load() async =>
      jsonDecode(await secrets.read('pin') ?? '{}') as Map<String, dynamic>;
  Future<List<int>> _hash(String pin, List<int> salt, int rounds) =>
      Isolate.run(
        () async => (await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: rounds,
          bits: 256,
        ).deriveKeyFromPassword(password: pin, nonce: salt)).extractBytes(),
      );
  Future<void> set(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const SetupFailure(SetupFailureReason.pinFormat);
    }
    final random = Random.secure();
    final salt = List.generate(16, (_) => random.nextInt(256));
    await secrets.write(
      'pin',
      jsonEncode({
        'salt': base64Encode(salt),
        'hash': base64Encode(await _hash(pin, salt, iterations)),
        'rounds': iterations,
        'failures': 0,
        'level': 0,
        'until': 0,
      }),
    );
  }

  Future<Duration> remaining() async {
    final data = await _load();
    return Duration(
      milliseconds: max(
        0,
        (data['until'] as int? ?? 0) - now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<bool> verify(String pin) async {
    if (_busy) return false;
    _busy = true;
    try {
      final data = await _load();
      if (data.isEmpty || (await remaining()) > Duration.zero) return false;
      final actual = await _hash(
        pin,
        base64Decode(data['salt'] as String),
        data['rounds'] as int,
      );
      final expected = base64Decode(data['hash'] as String);
      var difference = actual.length ^ expected.length;
      for (var i = 0; i < actual.length; i++) {
        difference |= actual[i] ^ expected[i];
      }
      if (difference == 0) {
        data.addAll({'failures': 0, 'level': 0, 'until': 0});
      } else {
        final failures = (data['failures'] as int) + 1;
        data['failures'] = failures;
        if (failures >= 5) {
          final level = data['level'] as int;
          data.addAll({
            'failures': 0,
            'level': min(level + 1, 10),
            'until': now()
                .add(Duration(seconds: 30 * (1 << level)))
                .millisecondsSinceEpoch,
          });
        }
      }
      await secrets.write('pin', jsonEncode(data));
      return difference == 0;
    } finally {
      _busy = false;
    }
  }
}
