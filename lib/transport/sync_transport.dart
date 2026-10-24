import 'sync_envelope.dart';

abstract interface class SyncTransport {
  Future<bool> send(SyncEnvelope envelope);
  Future<SyncEnvelope?> receive();
}

class FakeTransport implements SyncTransport {
  final List<String> _queue = [];
  @override
  Future<bool> send(SyncEnvelope envelope) async {
    _queue.add(envelope.encode());
    return true;
  }

  @override
  Future<SyncEnvelope?> receive() async =>
      _queue.isEmpty ? null : SyncEnvelope.decode(_queue.removeAt(0));
}
