/// Overall probe rating from the feedback engine (research doc 6.1).
enum ProbeOutcome { positive, stable, mixed, negative }

/// Therapist-facing summary from the status matrix (research doc 8.3). It is
/// a prompt for review, not a diagnosis.
enum ParticipantStatus {
  onTrack,
  plateau,
  adherenceProblem,
  needsReview,
  improvingDespiteLowPractice,
  awaitingProbe;

  /// Applies the matrix. [highAdherence] is adherence at or above the study
  /// threshold. Without a probe rating the status cannot be decided.
  static ParticipantStatus from({
    required bool highAdherence,
    required ProbeOutcome? probe,
  }) => switch ((highAdherence, probe)) {
    (_, null) => awaitingProbe,
    (_, ProbeOutcome.negative) => needsReview,
    (true, ProbeOutcome.positive) => onTrack,
    (true, _) => plateau,
    (false, ProbeOutcome.positive) => improvingDespiteLowPractice,
    (false, _) => adherenceProblem,
  };
}
