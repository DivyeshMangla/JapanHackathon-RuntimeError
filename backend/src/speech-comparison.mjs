// These are comparisons of a recognizer's text, never phonetic or clinical scores.
export function normalizeRecognizedText(value) {
  return value.normalize('NFKC').toLowerCase().replace(/[\p{P}\p{S}]+/gu, ' ').replace(/\s+/gu, ' ').trim();
}

function editDistance(expected, recognized) {
  let previous = Array.from({ length: recognized.length + 1 }, (_, index) => index);
  for (let row = 1; row <= expected.length; row++) {
    const current = [row];
    for (let column = 1; column <= recognized.length; column++) {
      current[column] = Math.min(current[column - 1] + 1, previous[column] + 1, previous[column - 1] + (expected[row - 1] === recognized[column - 1] ? 0 : 1));
    }
    previous = current;
  }
  return previous[recognized.length];
}

export function compareRecognizedText(expectedText, recognizedText) {
  const expected = normalizeRecognizedText(expectedText);
  const recognized = typeof recognizedText === 'string' ? normalizeRecognizedText(recognizedText) : '';
  if (!expected || !recognized) return { status: 'unavailable', expectedText, recognizedText: recognizedText || null, normalizedExpected: expected, normalizedRecognized: recognized || null, characterEditDistance: null, wordEditDistance: null, textSimilarityPercent: null };
  const expectedCharacters = Array.from(expected), recognizedCharacters = Array.from(recognized);
  const characterEditDistance = editDistance(expectedCharacters, recognizedCharacters);
  return {
    status: expected === recognized ? 'same_text' : 'different_text', expectedText, recognizedText,
    normalizedExpected: expected, normalizedRecognized: recognized,
    characterEditDistance,
    wordEditDistance: editDistance(expected.split(' '), recognized.split(' ')),
    textSimilarityPercent: Number((100 * (1 - characterEditDistance / Math.max(expectedCharacters.length, recognizedCharacters.length))).toFixed(1)),
    method: 'Unicode NFKC, lowercase, punctuation and whitespace normalization; code-point Levenshtein distance divided by the longer text length.',
    interpretation: 'Text similarity only. Recognition errors, language and accent can change this value; it is not pronunciation accuracy.',
  };
}

export function compareAudioTiming(referenceQuality, attemptQuality) {
  const reference = referenceQuality?.durationSeconds, attempt = attemptQuality?.durationSeconds;
  if (!(reference > 0) || !(attempt > 0)) return { status: 'unavailable', referenceDurationSeconds: reference ?? null, attemptDurationSeconds: attempt ?? null, durationRatio: null, interpretation: 'A supported reference and attempt recording are required for duration comparison.' };
  return {
    status: 'timing_only', referenceDurationSeconds: reference, attemptDurationSeconds: attempt,
    durationRatio: Number((attempt / reference).toFixed(3)),
    interpretation: 'Total recording duration includes pauses and silence. Adult and child pitch, pacing and recording conditions differ. This is context for listening, not an acoustic similarity or pronunciation score.',
  };
}
