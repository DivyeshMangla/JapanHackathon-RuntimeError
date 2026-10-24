import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/app_failure.dart';

/// Decoded JSON object. It exists only between this client and the
/// repositories that turn it into typed models.
typedef JsonObject = Map<String, Object?>;

const _connectTimeout = Duration(seconds: 10);
const _responseTimeout = Duration(seconds: 30);

/// Where the session token is kept between launches.
abstract interface class SessionTokenStore {
  Future<String?> read();

  Future<void> write(String? token);
}

class SecureSessionTokenStore implements SessionTokenStore {
  const SecureSessionTokenStore([this._storage = const FlutterSecureStorage()]);

  static const _key = 'backend_session_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? token) => token == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: token);
}

/// JSON over HTTP to the care service. Holds the bearer token and turns
/// every transport or server problem into a [NetworkFailure].
class BackendClient {
  BackendClient({required this.baseUrl, required SessionTokenStore tokens})
    : _tokens = tokens;

  final String baseUrl;
  final SessionTokenStore _tokens;
  String? _token;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _token = await _tokens.read();
    _loaded = true;
  }

  Future<bool> get hasSession async {
    await _ensureLoaded();
    return _token != null;
  }

  Future<void> setToken(String? token) async {
    _token = token;
    _loaded = true;
    await _tokens.write(token);
  }

  Future<JsonObject> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<JsonObject> post(String path, {JsonObject? body}) =>
      _send('POST', path, body: body ?? const {});

  Future<JsonObject> put(String path, {required JsonObject body}) =>
      _send('PUT', path, body: body);

  Future<JsonObject> patch(String path, {required JsonObject body}) =>
      _send('PATCH', path, body: body);

  Future<JsonObject> delete(String path) => _send('DELETE', path);

  Future<Uint8List> getBytes(String path) async {
    final response = await _execute('GET', path);
    if (response.status >= 400) throw _rejection(response);
    return response.bytes;
  }

  Future<JsonObject> _send(
    String method,
    String path, {
    JsonObject? body,
    Map<String, String>? query,
  }) async {
    final response = await _execute(method, path, body: body, query: query);
    final decoded = _decode(response.bytes);
    if (response.status >= 400) throw _rejection(response, decoded);
    if (decoded == null) throw const NetworkFailure(NetworkProblem.badResponse);
    return decoded;
  }

  Future<({int status, Uint8List bytes})> _execute(
    String method,
    String path, {
    JsonObject? body,
    Map<String, String>? query,
  }) async {
    await _ensureLoaded();
    final client = HttpClient()..connectionTimeout = _connectTimeout;
    try {
      final uri = Uri.parse(
        '$baseUrl/api$path',
      ).replace(queryParameters: query);
      final request = await client.openUrl(method, uri);
      final token = _token;
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(_responseTimeout);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(_responseTimeout)) {
        builder.add(chunk);
      }
      return (status: response.statusCode, bytes: builder.takeBytes());
    } on TimeoutException {
      throw const NetworkFailure(NetworkProblem.timeout);
    } on IOException {
      throw const NetworkFailure(NetworkProblem.offline);
    } finally {
      client.close(force: true);
    }
  }

  JsonObject? _decode(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  NetworkFailure _rejection(
    ({int status, Uint8List bytes}) response, [
    JsonObject? decoded,
  ]) {
    final message = (decoded ?? _decode(response.bytes))?['error'];
    return NetworkFailure(
      response.status == 401
          ? NetworkProblem.sessionEnded
          : NetworkProblem.rejected,
      status: response.status,
      serverMessage: message is String ? message : null,
    );
  }
}

extension JsonObjectReading on JsonObject {
  /// The list of objects under [key], or an empty list when it is absent.
  List<JsonObject> objects(String key) => [
    for (final item in (this[key] as List<Object?>? ?? const []))
      item! as JsonObject,
  ];

  JsonObject object(String key) {
    final value = this[key];
    if (value is! JsonObject) {
      throw const NetworkFailure(NetworkProblem.badResponse);
    }
    return value;
  }
}

/// Supplied in `main` once the server address is known.
final backendClientProvider = Provider<BackendClient>(
  (ref) => throw StateError('backendClientProvider was not overridden'),
);
