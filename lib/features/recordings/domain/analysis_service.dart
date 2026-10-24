import 'recording.dart';

/// Voice analysis seam. A real implementation would run acoustic measures
/// (for example on-device or on a self-hosted server) and report progress
/// per recording through [AnalysisStatus] (research doc section 6). Callers
/// depend only on this interface.
abstract interface class AnalysisService {
  Future<AnalysisStatus> statusOf(Recording recording);
}

/// Placeholder used by the prototype. It performs no signal processing:
/// every recording is pending.
class StubAnalysisService implements AnalysisService {
  const StubAnalysisService();

  // TODO(analysis): replace with a real AnalysisService implementation.
  @override
  Future<AnalysisStatus> statusOf(Recording recording) async =>
      AnalysisStatus.pending;
}
