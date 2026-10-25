abstract final class WordStrings {
  static const generateReport = 'Generate voice report';
  static const regenerateReport = 'Generate voice report again';
  static const reportPending = 'Recognizing speech and generating the report…';
  static const reportReady = 'Voice recognition report ready for review';
  static const reportFailed = 'Speech recognition failed. You can try again.';
  static const reportPermission =
      'Parent permission is needed for speech recognition.';
  static const reportManual =
      'This recording needs manual listening and review.';
  static String reportStatus(String? status) => switch (status) {
    'pending' => reportPending,
    'complete' => reportReady,
    'failed' => reportFailed,
    'unconfigured' => mock,
    'declined' || 'hosted_consent_required' => reportPermission,
    'quality_blocked' => reportManual,
    _ => unavailable,
  };
  static const title = 'Say a word';
  static const guidance = 'Listen if you like. Try the word when you’re ready.';
  static const scope =
      'Therapist-guided speech practice. This is not a validated standalone treatment and does not guarantee speech improvement.';
  static const empty = 'Your therapist has not assigned a word yet.';
  static const listen = 'Listen';
  static const record = 'Record';
  static const stopRecording = 'Stop recording';
  static const recording =
      'Recording is on. Tap Stop recording when you’re ready.';
  static const replay = 'Play my recording';
  static const delete = 'Delete recording';
  static const again = 'Record again';
  static const send = 'Send to therapist';
  static const skip = 'Try another word';
  static const next = 'Next word';
  static const uploading = 'Uploading…';
  static const delivered = 'Delivered to your therapist';
  static const failed =
      'Upload failed. Retry, or delete this attempt and record again.';
  static const retry = 'Retry';
  static const back = 'Back';
  static const done = 'You can finish here. Thank you for trying.';
  static const stopPlayback = 'Stop playing';
  static const error = 'Something did not work. Please try again.';
  static const micDenied =
      'Microphone access is needed only to record. You can allow it in device settings, or skip.';
  static const interrupted =
      'Recording stopped because the app left the foreground. You can listen to your attempt or delete it.';
  static const ai = 'AI suggestion—may be inaccurate.';
  static const noTranscript = 'Could not transcribe.';
  static const transcribing =
      'Transcript pending. Original recording is delivered.';
  static const mock =
      'Speech recognition is not configured. Original recordings are delivered for therapist assessment. Automated pronunciation accuracy is unavailable.';
  static const reportTitle =
      'Automated observations requiring therapist review';
  static const matchTitle = 'Speech recognition match';
  static const matchWord = 'Target word';
  static const matchExample = 'Your example';
  static const matchCaption =
      'Recognized text only, not pronunciation accuracy. Listen before rating.';
  static const notAssessable = 'n/a';
  static const details = 'Details';
  static const unable = 'Unable to assess reliably';
  static const target = 'Target word';
  static const recognized = 'Recognized text (unverified)';
  static const unavailable = 'Unavailable';
  static const accuracyUnavailable =
      'Pronunciation accuracy: unavailable. No validated model is configured.';
  static const soundsUnavailable = 'Possible sound differences: not assessed.';
  static const confidenceUnavailable =
      'Model confidence: unavailable. Recognition confidence is not pronunciation accuracy.';
  static const sameText =
      'Recognized text matches the target. This is a text comparison only.';
  static const differentText =
      'Recognized text differs from the target. This does not identify sound differences.';
  static const correction = 'Therapist correction of analysis (optional)';
  static const correctionHint =
      'Keep your correction separate from the automated estimate. Only feedback is shown to the child.';
  static const assessment = 'Therapist assessment';
  static const assessmentHint =
      'This is your assessment of this attempt. It is shared with the family when marked reviewed.';
  static const correct = 'Correct for this goal';
  static const needsPractice = 'Keep practising';
  static const notAssessed = 'Not assessed';
  static const captureTitle = 'Technical capture checks';
  static const captureChecked =
      'Level, duration and clipping checked. This does not establish intelligibility or speech presence.';
  static const captureBlocked =
      'Capture checks need attention. Listen to the original recording.';
  static const captureUnavailable =
      'Capture checks could not assess this recording.';
  static const model = 'Speech recognizer';
  static const textSimilarity = 'Target and recognized text similarity (%)';
  static const textSimilarityHint =
      'Calculated from text edit distance. This is not pronunciation accuracy.';
  static const characterEdits = 'Character edits';
  static const wordEdits = 'Word edits';
  static const referenceOriginal = 'Play example saved with this attempt';
  static const referenceRecognized = 'Example recognized text (unverified)';
  static const referenceReview =
      'The example transcript differs from the target. Listen to the example before interpreting this comparison.';
  static const referenceUnavailable =
      'An example transcript is unavailable. Listen to the original example.';
  static const referenceSimilarity =
      'Example and child transcript similarity (%)';
  static const referenceDuration = 'Example duration (seconds)';
  static const durationRatio = 'Child / example recording duration';
  static const timingHint =
      'Duration includes silence and pauses. Timing and adult-child voice differences are not pronunciation scores.';
  static const duration = 'Duration (seconds)';
  static const sampleRate = 'Sample rate (Hz)';
  static const level = 'Level (dBFS)';
  static const clipping = 'Clipped samples (%)';
  static const feedback = 'Therapist feedback';
  static const playFeedback = 'Listen to feedback';
  static const therapist = 'Words and recordings';
  static const askParent =
      'Ask your grown-up to sign the consent in their Melo app first.';
  static const assign = 'Assign a word';
  static const word = 'Useful word';
  static const example = 'Example recording';
  static const exampleAnalysisNotice =
      'If the parent allows online analysis, your example recording and the child’s attempt may be sent to the online analysis provider for comparison. Originals are kept for therapist review.';
  static const chooseExample = 'Choose example WAV';
  static const assignHint =
      'Enter a word and record or choose your own example. No timer or repetition target is assigned.';
  static const required = 'Please complete this field.';
  static const save = 'Save';
  static const reviewed = 'Reviewed';
  static const markReviewed = 'Reviewed — share feedback with child and parent';
  static const review = 'Save feedback and review status';
  static const original = 'Play original recording';
  static const noAttempts = 'No recordings have been delivered yet.';
  static const feedbackHint = 'Written feedback (optional)';
  static const voiceFeedback = 'Record feedback (optional)';
  static const saved = 'Saved';
  static const selected = 'File selected';
  static const tooLarge = 'Please choose a WAV recording up to 12 MB.';
  static const continuePractice = 'Continue';
}
