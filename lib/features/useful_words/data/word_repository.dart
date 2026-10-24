import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../domain/useful_word.dart';

typedef WordRequest =
    Future<Map<String, dynamic>> Function(
      String path, {
      String method,
      Map<String, dynamic>? data,
    });

/// One child's word practice on the care service. An attempt that fails to
/// send waits in the device's encrypted storage until it is delivered or
/// discarded. The transport and store are passed in so tests can fake them.
class WordRepository {
  WordRepository(this.patientId, this._request, this._read, this._write);
  final String patientId;
  final WordRequest _request;
  final String? Function() _read;
  final Future<void> Function(String?) _write;
  String get _path => '/useful-words/patients/$patientId';

  Future<WordPractice> load() async =>
      WordPractice.fromJson(await _request(_path));
  Future<void> enroll(String birthDate) async {
    await _request(
      '$_path/enrollment',
      method: 'PUT',
      data: {
        'birthDate': birthDate,
        'usesSpeech': true,
        'therapistSelectedGoals': true,
      },
    );
  }

  Future<void> assign(
    String word,
    Uint8List picture,
    String mime,
    Uint8List example,
  ) async {
    await _request(
      '$_path/words',
      method: 'POST',
      data: {
        'word': word,
        'picture': 'data:$mime;base64,${base64Encode(picture)}',
        'exampleAudio': base64Encode(example),
      },
    );
  }

  Future<Uint8List> audio(
    String kind,
    String id, {
    bool feedback = false,
  }) async {
    final response = await _request(
      '$_path/$kind/$id/${feedback ? 'feedback' : 'audio'}',
    );
    return base64Decode(response['audio'] as String);
  }

  PendingWordAttempt? get pending {
    final value = _read();
    return value == null
        ? null
        : PendingWordAttempt.fromJson(
            jsonDecode(value) as Map<String, dynamic>,
          );
  }

  Future<PendingWordAttempt> queue(String wordId, Uint8List audio) async {
    // A failed submission is immutable until delivered or explicitly discarded.
    final existing = pending;
    if (existing != null) return existing;
    final attempt = PendingWordAttempt(
      id: const Uuid().v4(),
      wordId: wordId,
      audio: base64Encode(audio),
    );
    await _write(jsonEncode(attempt.toJson()));
    return attempt;
  }

  Future<void> deliver() async {
    final attempt = pending;
    if (attempt == null) return;
    await _request('$_path/attempts', method: 'POST', data: attempt.toJson());
    await _write(null);
  }

  Future<void> discard() => _write(null);
  Future<void> review(
    String id,
    String feedback,
    bool reviewed, {
    Uint8List? audio,
    bool preserveAudio = false,
    String? analysisCorrection,
  }) async {
    await _request(
      '$_path/attempts/$id/review',
      method: 'PUT',
      data: {
        'feedback': feedback,
        'reviewed': reviewed,
        'feedbackAudio': audio == null ? null : base64Encode(audio),
        'preserveAudio': preserveAudio,
        'analysisCorrection': ?analysisCorrection,
      },
    );
  }
}
