import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/connected_failure.dart';
import '../../../core/errors/setup_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../crypto/pin_service.dart';
import '../../../data/setup_repository.dart';
import '../domain/connected_models.dart';

const _connectTimeout = Duration(seconds: 10);
const _responseTimeout = Duration(seconds: 30);

/// The connected account on this phone: the API client, an encrypted cache
/// of what the screens last showed, and an outbox of practice waiting to
/// upload. The store is separate from the offline study installation and
/// scoped to the API origin; each account's cache and outbox is keyed by its
/// server user id, so a shared phone never mixes two people's data.
class ConnectedService extends ChangeNotifier {
  ConnectedService(this.baseUrl, this._box, this._secrets);

  final String baseUrl;
  final Box<String> _box;
  final SecretStore _secrets;
  String? _token;
  ConnectedUser? _user;
  ConnectedConfig _config = ConnectedConfig.empty;
  PatientRecord? _patientRecord;
  List<PatientSummary> _patients = const [];
  bool _locked = false;
  bool _needsPin = false;
  bool _biometricsEnabled = false;
  bool _syncing = false;
  bool _offline = false;
  ConnectedFailure? _syncFailure;
  Future<void> _writes = Future.value();

  ConnectedUser? get user => _user;
  ConnectedConfig get config => _config;

  /// The signed-in patient's own record, from the server or the cache.
  PatientRecord? get patientRecord => _patientRecord;

  /// The signed-in therapist's caseload.
  List<PatientSummary> get patients => _patients;
  bool get isTherapist => _user?.role == ConnectedRole.therapist;

  /// Therapist accounts hold other people's records, so they are behind a
  /// PIN on every launch and after time in the background.
  bool get locked => _locked;
  bool get needsPin => _needsPin;
  bool get biometricsEnabled => _biometricsEnabled;
  bool get syncing => _syncing;
  bool get offline => _offline;
  ConnectedFailure? get syncFailure => _syncFailure;

  String get _userId => _user!.id;
  SecretStore get _accountSecrets => _AccountSecrets(_secrets, _userId);
  PinService get _pin => PinService(_accountSecrets);

  List<OutboxItem> get outbox => _user == null
      ? const []
      : [for (final entry in _readList('outbox:$_userId')) _outboxItem(entry)];

  static Future<ConnectedService> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const ConnectedFailure(ConnectedFailureReason.invalidServerAddress);
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw const ConnectedFailure(ConnectedFailureReason.httpsRequired);
    }
    final origin = '${uri.scheme}://${uri.authority}';
    final namespace = base64Url.encode(utf8.encode(origin));
    final secrets = _SecureSecrets('connected:$namespace:');
    var key = await secrets.read('databaseKey');
    if (key == null) {
      key = base64Encode(
        List.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await secrets.write('databaseKey', key);
    }
    await Hive.initFlutter();
    final box = await Hive.openBox<String>(
      'connected_$namespace',
      encryptionCipher: HiveAesCipher(base64Decode(key)),
    );
    final service = ConnectedService(origin, box, secrets);
    await service.restore();
    return service;
  }

  Future<void> restore() async {
    _config = _readConfig();
    final token = await _secrets.read('session');
    // Sign-out leaves an empty token behind rather than deleting the key.
    _token = token == null || token.isEmpty ? null : token;
    final cachedUser = _token == null ? null : _readMap('user');
    _user = cachedUser == null ? null : ConnectedUser.fromJson(cachedUser);
    if (_user != null) await _loadAccountState();
    try {
      await _refreshConfig();
      if (_user != null) {
        final me = await _request('/auth/me');
        _user = ConnectedUser.fromJson(me['user'] as Map<String, dynamic>);
        await _box.put('user', jsonEncode(_user!.toJson()));
        if (!_locked) await refresh();
      }
    } on ConnectedFailure catch (failure) {
      if (failure.endsSession) {
        await _clearSession();
      } else {
        _offline = true;
        _syncFailure = failure;
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    final result = await _request(
      '/auth/login',
      method: 'POST',
      data: {'email': email.trim(), 'password': password, 'client': 'mobile'},
    );
    final signedIn = ConnectedUser.fromJson(
      result['user'] as Map<String, dynamic>,
    );
    _token = result['token'] as String;
    if (signedIn.role == ConnectedRole.admin) {
      // Revoke the session the server just issued, so a rejected role
      // leaves no usable token behind.
      await _request('/auth/logout', method: 'POST', data: const {});
      _token = null;
      throw const ConnectedFailure(ConnectedFailureReason.adminUsesDashboard);
    }
    _user = signedIn;
    await _secrets.write('session', _token!);
    await _box.put('user', jsonEncode(signedIn.toJson()));
    await _loadAccountState();
    _offline = false;
    notifyListeners();
    if (!_locked) await refresh();
  }

  Future<void> register(Registration registration) => _request(
    '/auth/register',
    method: 'POST',
    data: {
      'role': registration.role.name,
      'name': registration.name,
      'email': registration.email.trim(),
      'password': registration.password,
      'clinic': registration.clinic,
      'registration': registration.registrationNumber,
    },
  );

  Future<void> setPin(
    String value,
    String confirm, {
    bool biometrics = false,
  }) async {
    if (value != confirm) {
      throw const ConnectedFailure(ConnectedFailureReason.pinMismatch);
    }
    try {
      await _pin.set(value);
    } on SetupFailure {
      throw const ConnectedFailure(ConnectedFailureReason.pinFormat);
    }
    await _accountSecrets.write('biometrics', '$biometrics');
    _biometricsEnabled = biometrics;
    _needsPin = false;
    _locked = false;
    notifyListeners();
    await refresh();
  }

  Future<void> unlock(String value) async {
    if (!await _pin.verify(value)) {
      final remaining = await _pin.remaining();
      throw remaining > Duration.zero
          ? ConnectedFailure(
              ConnectedFailureReason.pinLocked,
              retryAfter: remaining,
            )
          : const ConnectedFailure(ConnectedFailureReason.wrongPin);
    }
    _locked = false;
    notifyListeners();
    await refresh();
  }

  Future<void> unlockBiometric(Future<bool> Function() authenticate) async {
    if (!_biometricsEnabled) {
      throw const ConnectedFailure(ConnectedFailureReason.biometricsDisabled);
    }
    final remaining = await _pin.remaining();
    if (remaining > Duration.zero) {
      throw ConnectedFailure(
        ConnectedFailureReason.pinLocked,
        retryAfter: remaining,
      );
    }
    if (await authenticate()) {
      _locked = false;
      notifyListeners();
      await refresh();
    }
  }

  /// Online account verification allows replacing this device's forgotten
  /// PIN. It never grants access until a replacement PIN has been saved.
  Future<void> recoverPin(String password) async {
    final result = await _request(
      '/auth/login',
      method: 'POST',
      data: {'email': _user!.email, 'password': password, 'client': 'mobile'},
    );
    final replacement = result['token'] as String;
    // Revoke the old token while it is still the active request credential.
    if (_token != null) {
      await _request('/auth/logout', method: 'POST', data: const {});
    }
    _token = replacement;
    await _secrets.write('session', replacement);
    _needsPin = true;
    _locked = true;
    notifyListeners();
  }

  void lock() {
    if (!isTherapist) return;
    _locked = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_user == null || _locked) return;
    try {
      await _refreshConfig();
      if (isTherapist) {
        final result = await _request('/patients');
        final rows = (result['patients'] as List).cast<Map<String, dynamic>>();
        _patients = [for (final row in rows) PatientSummary.fromJson(row)];
        await _box.put('patients:$_userId', jsonEncode(rows));
      } else {
        final result = await _request('/patients/$_userId');
        _patientRecord = PatientRecord.fromJson(result);
        await _box.put('patient:$_userId', jsonEncode(result));
      }
      _offline = false;
      _syncFailure = null;
      await sync();
    } on ConnectedFailure catch (failure) {
      if (failure.endsSession) {
        await _clearSession();
        _syncFailure = const ConnectedFailure(
          ConnectedFailureReason.sessionEnded,
        );
      } else {
        _offline = true;
        _syncFailure = failure;
      }
    }
    notifyListeners();
  }

  Future<void> submitConsent({
    required Map<ConsentStatement, bool> answers,
    required List<int> signaturePng,
  }) async {
    await _request(
      '/patients/$_userId/consent',
      method: 'POST',
      data: {
        'version': _config.consentVersion,
        'signerName': _user!.name,
        'checks': {
          for (final statement in ConsentStatement.values)
            statement.name: answers[statement] == true,
        },
        'signaturePng': base64Encode(signaturePng),
      },
    );
    await refresh();
  }

  Future<PatientRecord> patient(String patientId) async =>
      PatientRecord.fromJson(await _request('/patients/$patientId'));

  Future<void> approveConsent(String patientId) => _request(
    '/patients/$patientId/approve-consent',
    method: 'POST',
    data: const {'paperCopy': true},
  );

  Future<void> saveForms(String patientId, ClinicalForms forms) => _request(
    '/patients/$patientId/forms',
    method: 'PUT',
    data: {
      'age': forms.age,
      'demographic': forms.demographic,
      'clinical': forms.clinical,
    },
  );

  Future<void> prescribe(String patientId, PlanDraft plan) => _request(
    '/patients/$patientId/plans',
    method: 'POST',
    data: {
      'title': plan.title,
      'exercises': plan.exerciseIds,
      'sessionsPerDay': plan.sessionsPerDay,
      'notes': plan.notes,
    },
  );

  Future<void> reviewRecording(String recordingId, String note) => _request(
    '/recordings/$recordingId/review',
    method: 'POST',
    data: {'note': note},
  );

  Future<void> savePractice({
    required String planId,
    required String exerciseId,
    required int minutes,
  }) => _enqueue(OutboxKind.progress, {
    'id': const Uuid().v4(),
    'planId': planId,
    'exerciseId': exerciseId,
    'minutes': minutes,
    'completedAt': DateTime.now().toUtc().toIso8601String(),
  });

  Future<void> saveRecording({
    required String planId,
    required String exerciseId,
    required List<int> audio,
    required int seconds,
  }) => _enqueue(OutboxKind.recordings, {
    'id': const Uuid().v4(),
    'planId': planId,
    'exerciseId': exerciseId,
    'audio': base64Encode(audio),
    'durationSeconds': seconds,
  });

  /// Uploads the outbox in order. An item leaves the outbox only after the
  /// server accepted it, and the server ignores a repeated id, so a retry
  /// after a lost response never duplicates practice.
  Future<void> sync() async {
    if (_syncing || _user == null || _locked) return;
    final owner = _userId;
    _syncing = true;
    notifyListeners();
    try {
      for (final entry in _readList('outbox:$owner')) {
        if (_user?.id != owner || _locked) break;
        final payload = entry['payload'] as Map<String, dynamic>;
        await _request(
          '/patients/$owner/${entry['kind']}',
          method: 'POST',
          data: payload,
        );
        await _write(() async {
          final remaining = _readList('outbox:$owner')
            ..removeWhere((e) => (e['payload'] as Map)['id'] == payload['id']);
          await _box.put('outbox:$owner', jsonEncode(remaining));
          await _box.flush();
        });
      }
      _offline = false;
      _syncFailure = null;
    } on ConnectedFailure catch (failure) {
      _offline = failure.status == 0;
      _syncFailure = failure;
      if (failure.endsSession) await _clearSession();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> changePassword(String current, String next) async {
    await _request(
      '/auth/password',
      method: 'POST',
      data: {'currentPassword': current, 'password': next},
    );
    await _clearSession();
  }

  Future<Uint8List> recordingAudio(String recordingId) async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client.getUrl(
        Uri.parse('$baseUrl/api/recordings/$recordingId/audio'),
      );
      request.headers.set('Authorization', 'Bearer $_token');
      final response = await request.close().timeout(_responseTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw ConnectedFailure(
          ConnectedFailureReason.recordingUnavailable,
          status: response.statusCode,
        );
      }
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add).timeout(_responseTimeout);
      return builder.takeBytes();
    } on IOException {
      throw const ConnectedFailure(ConnectedFailureReason.offline);
    } on TimeoutException {
      throw const ConnectedFailure(ConnectedFailureReason.timeout);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> signOut() async {
    // Online logout revokes the server token. Offline logout still removes
    // the device token; the server session expires after its bounded
    // lifetime, so a failed request does not block signing out.
    try {
      await _request('/auth/logout', method: 'POST', data: const {});
    } on ConnectedFailure catch (failure) {
      AppLogger.warning('Connected sign-out could not revoke the session');
      _syncFailure = failure.reason == ConnectedFailureReason.offline
          ? null
          : failure;
    }
    await _clearSession();
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('$baseUrl/api$path'),
      );
      if (_token != null) {
        request.headers.set('Authorization', 'Bearer $_token');
      }
      if (data != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(data));
      }
      final response = await request.close().timeout(_responseTimeout);
      final content = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_responseTimeout);
      final result = jsonDecode(content);
      if (result is! Map<String, dynamic>) {
        throw const ConnectedFailure(ConnectedFailureReason.badResponse);
      }
      if (response.statusCode >= 400) {
        throw ConnectedFailure(
          ConnectedFailureReason.rejected,
          status: response.statusCode,
          serverMessage: result['error'] as String?,
        );
      }
      return result;
    } on IOException {
      throw const ConnectedFailure(ConnectedFailureReason.offline);
    } on TimeoutException {
      throw const ConnectedFailure(ConnectedFailureReason.timeout);
    } on FormatException {
      throw const ConnectedFailure(ConnectedFailureReason.badResponse);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _refreshConfig() async {
    final result = await _request('/config');
    _config = ConnectedConfig.fromJson(result);
    await _box.put('config', jsonEncode(result));
  }

  Future<void> _loadAccountState() async {
    final cachedRecord = _readMap('patient:$_userId');
    _patientRecord = cachedRecord == null
        ? null
        : PatientRecord.fromJson(cachedRecord);
    _patients = [
      for (final row in _readList('patients:$_userId'))
        PatientSummary.fromJson(row),
    ];
    _needsPin = isTherapist && await _accountSecrets.read('pin') == null;
    _locked = isTherapist;
    _biometricsEnabled = await _accountSecrets.read('biometrics') == 'true';
  }

  ConnectedConfig _readConfig() {
    final cached = _readMap('config');
    return cached == null
        ? ConnectedConfig.empty
        : ConnectedConfig.fromJson(cached);
  }

  Map<String, dynamic>? _readMap(String key) {
    final raw = _box.get(key);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _readList(String key) =>
      (jsonDecode(_box.get(key) ?? '[]') as List).cast<Map<String, dynamic>>();

  static OutboxItem _outboxItem(Map<String, dynamic> entry) {
    final payload = entry['payload'] as Map<String, dynamic>;
    return OutboxItem(
      id: payload['id'] as String,
      kind: OutboxKind.values.byName(entry['kind'] as String),
      planId: payload['planId'] as String,
      exerciseId: payload['exerciseId'] as String,
    );
  }

  // Serialize local outbox writes so recording completion cannot overwrite a
  // progress event while a sync request is in flight.
  Future<void> _write(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> _enqueue(OutboxKind kind, Map<String, dynamic> payload) async {
    final owner = _userId;
    await _write(() async {
      final entries = _readList('outbox:$owner')
        ..add({'kind': kind.name, 'payload': payload});
      await _box.put('outbox:$owner', jsonEncode(entries));
      await _box.flush();
    });
    notifyListeners();
    await sync();
  }

  Future<void> _clearSession() async {
    await _secrets.write('session', '');
    await _box.delete('user');
    _token = null;
    _user = null;
    _patientRecord = null;
    _patients = const [];
    _locked = false;
    _needsPin = false;
    _biometricsEnabled = false;
    notifyListeners();
  }
}

class _SecureSecrets implements SecretStore {
  _SecureSecrets(this.prefix);

  final String prefix;
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: '$prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$prefix$key', value: value);

  @override
  Future<void> clear() async {
    for (final key in (await _storage.readAll()).keys) {
      if (key.startsWith(prefix)) await _storage.delete(key: key);
    }
  }
}

/// One account's secrets within the origin's store. Clearing is refused so a
/// PIN can only be replaced through account recovery.
class _AccountSecrets implements SecretStore {
  _AccountSecrets(this.parent, this.id);

  final SecretStore parent;
  final String id;

  @override
  Future<String?> read(String key) => parent.read('$id:$key');

  @override
  Future<void> write(String key, String value) =>
      parent.write('$id:$key', value);

  @override
  Future<void> clear() async =>
      throw UnsupportedError('Account secrets require explicit recovery.');
}
