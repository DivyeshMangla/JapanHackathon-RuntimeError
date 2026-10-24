import 'package:flutter/foundation.dart';

/// The care service origin, e.g. `https://care.example.org`, or a
/// [FormatException] when [address] cannot be used. Release builds must use
/// HTTPS because recordings and records travel to the service.
String validatedServerOrigin(String address) {
  final uri = Uri.tryParse(address);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw FormatException('Not a server address', address);
  }
  if (kReleaseMode && uri.scheme != 'https') {
    throw FormatException('Release builds require HTTPS', address);
  }
  return '${uri.scheme}://${uri.authority}';
}
