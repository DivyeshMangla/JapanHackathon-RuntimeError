// A transcript supports a text comparison, never a pronunciation score. No
// age/language/speech-characteristic validation evidence is configured here.
export function pronunciationReport(targetWord, transcript = null, processingStatus = 'complete') {
  const normalize = value => value.normalize('NFKC').trim().toLocaleLowerCase();
  const recognizedWord = typeof transcript === 'string' && transcript.trim() ? transcript.trim() : null;
  return {
    schemaVersion: 1,
    label: 'Automated estimate requiring therapist review',
    targetWord,
    recognizedWord,
    recognizedSounds: [],
    textComparison: recognizedWord ? (normalize(targetWord) === normalize(recognizedWord) ? 'same_text' : 'different_text') : 'unavailable',
    assessment: 'Unable to assess reliably',
    processingStatus,
    pronunciationAccuracy: null,
    possibleSoundDifferences: [],
    modelConfidence: null,
    modelId: null,
    validation: 'No pronunciation model validated for this child’s age, language and speech characteristics is configured.',
    limitations: [
      'Speech recognition confidence is not pronunciation accuracy.',
      'Recognized text may be inaccurate; matching or differing text does not establish pronunciation quality or sound differences.',
      'Recording clarity, noise, clipping and microphone distance have not been assessed by a validated recording-quality model.',
      'Recognized sounds, sound differences, model confidence and accuracy are unavailable without an appropriate validated model.',
      ...(processingStatus === 'failed' ? ['Recognition failed or timed out. Original audio remains available.'] : []),
      ...(processingStatus === 'pending' ? ['Recognition is pending. Original audio has already been delivered.'] : []),
    ],
  };
}

export async function recognizeWithDeadline(transcriber, audio, milliseconds = 15000) {
  let timer;
  try {
    return await Promise.race([
      Promise.resolve().then(() => transcriber.suggest(audio)),
      new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Recognition timed out')), milliseconds); timer.unref?.(); }),
    ]);
  } finally { clearTimeout(timer); }
}
