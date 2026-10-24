import '../../study/domain/participant_status.dart';
import 'recording.dart';

/// Voice analysis seam. A real implementation would run acoustic measures
/// (for example on-device or on a self-hosted server), report progress per
/// recording through [AnalysisStatus], and rate each patient's latest probe
/// against their baseline (research doc section 6). Callers depend only on
/// this interface.
abstract interface class AnalysisService {
  Future<AnalysisStatus> statusOf(Recording recording);

  /// The overall rating of the patient's latest probe, or null when there is
  /// none yet.
  Future<ProbeOutcome?> probeOutcome(String patientId);
}

/// Placeholder used by the prototype. It performs no signal processing:
/// every recording is pending and no probe has a rating.
class StubAnalysisService implements AnalysisService {
  const StubAnalysisService();

  // TODO(analysis): replace with a real AnalysisService implementation.
  @override
  Future<AnalysisStatus> statusOf(Recording recording) async =>
      AnalysisStatus.pending;

  @override
  Future<ProbeOutcome?> probeOutcome(String patientId) async => null;
}
