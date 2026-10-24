import { spawn } from 'node:child_process';
import { compareRecognizedText, compareAudioTiming } from './speech-comparison.mjs';

// These technical capture checks are deliberately conservative heuristics, not
// an age/language validated speech or pronunciation assessment.
export function assessWordAudio(bytes) {
  const unavailable = reason => ({ version: 1, status: 'unassessable', eligibleForRecognition: false, reasons: [reason], durationSeconds: null, sampleRate: null, channels: null, clippingFraction: null, rmsDbfs: null });
  if (!Buffer.isBuffer(bytes) || bytes.length < 44 || bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE' || bytes.readUInt32LE(4) + 8 !== bytes.length) return unavailable('WAV structure is incomplete or invalid.');
  let format = null, samples = null, offset = 12;
  while (offset + 8 <= bytes.length) {
    const kind = bytes.toString('ascii', offset, offset + 4), length = bytes.readUInt32LE(offset + 4);
    if (length > bytes.length - offset - 8) return unavailable('WAV contains a truncated audio chunk.');
    if (kind === 'fmt ') {
      if (format || length < 16) return unavailable('WAV format is ambiguous or incomplete.');
      format = { encoding: bytes.readUInt16LE(offset + 8), channels: bytes.readUInt16LE(offset + 10), sampleRate: bytes.readUInt32LE(offset + 12), byteRate: bytes.readUInt32LE(offset + 16), blockAlign: bytes.readUInt16LE(offset + 20), bits: bytes.readUInt16LE(offset + 22) };
    }
    if (kind === 'data') {
      if (samples) return unavailable('Multiple audio chunks require manual listening.');
      samples = bytes.subarray(offset + 8, offset + 8 + length);
    }
    offset += 8 + length + (length % 2);
  }
  if (offset !== bytes.length || !format || !samples?.length || format.encoding !== 1 || format.bits !== 16 || format.channels !== 1 || format.sampleRate < 8000 || format.sampleRate > 48000 || format.blockAlign !== 2 || format.byteRate !== format.sampleRate * 2 || samples.length % 2) return unavailable('Capture checks support complete 16-bit mono PCM WAV at 8–48 kHz. Listen to the original recording.');
  const count = samples.length / 2, durationSeconds = count / format.sampleRate;
  let squares = 0, clipped = 0, peak = 0;
  for (let i = 0; i < samples.length; i += 2) {
    const sample = samples.readInt16LE(i) / 32768;
    squares += sample * sample;
    peak = Math.max(peak, Math.abs(sample));
    if (Math.abs(sample) >= 0.999) clipped++;
  }
  const rmsDbfs = Math.max(-120, 10 * Math.log10(squares / count || 1e-12));
  const clippingFraction = clipped / count;
  const reasons = [];
  if (durationSeconds < 0.2) reasons.push('Recording is shorter than 0.2 seconds.');
  if (durationSeconds > 30) reasons.push('Recording is longer than the 30-second single-word analysis limit.');
  if (rmsDbfs < -55 || peak < 0.005) reasons.push('Recording is silent or very quiet.');
  if (clippingFraction > 0.01) reasons.push('More than 1% of samples reach the clipping threshold.');
  return { version: 1, status: reasons.length ? 'retake' : 'checked', eligibleForRecognition: reasons.length === 0, reasons, durationSeconds: Number(durationSeconds.toFixed(3)), sampleRate: format.sampleRate, channels: format.channels, clippingFraction: Number(clippingFraction.toFixed(6)), rmsDbfs: Number(rmsDbfs.toFixed(1)) };
}

export function pronunciationReport(targetWord, transcript = null, processingStatus = 'complete', { quality = null, modelId = null, language = null, provider = 'local', reference = null, recognitionEvidence = null } = {}) {
  const recognizedWord = typeof transcript === 'string' && transcript.trim() ? transcript.trim() : null;
  const comparison = compareRecognizedText(targetWord, recognizedWord);
  return {
    schemaVersion: 3,
    label: 'Automated observations requiring therapist review',
    targetWord, recognizedWord, recognizedSounds: [],
    textComparison: comparison.status, textSimilarity: comparison,
    assessment: 'Unable to assess reliably', processingStatus, pronunciationAccuracy: null,
    possibleSoundDifferences: [], modelConfidence: null, modelId, language,
    captureQuality: quality, provider, recognitionEvidence,
    reference: reference ? { wordId: reference.wordId, targetWord: reference.targetWord, audioDigest: reference.audioDigest, capturedAt: reference.capturedAt, captureQuality: reference.captureQuality, recognitionStatus:reference.recognitionStatus || 'unavailable', recognizedText:reference.recognizedText || null, textSimilarity:compareRecognizedText(reference.targetWord,reference.recognizedText), needsReview:reference.recognitionStatus === 'complete' && compareRecognizedText(reference.targetWord,reference.recognizedText).status !== 'same_text' } : null,
    referenceTranscriptComparison: compareRecognizedText(reference?.recognizedText || '',recognizedWord),
    audioComparison: compareAudioTiming(reference?.captureQuality, quality),
    validation: 'No pronunciation model validated for this child’s age, language and speech characteristics is configured.',
    limitations: [
      'Recognition receives an analysis copy; non-16 kHz recordings are locally resampled to 16 kHz. The original is preserved.',
      'Speech recognition confidence is not pronunciation accuracy.',
      'Recognized text may be inaccurate; matching or differing text does not establish pronunciation quality or sound differences.',
      'The therapist example is recognized independently without a target prompt. A mismatch requires listening to the example before interpreting its comparison with the child.',
      'Capture checks measure WAV duration, level and clipping only. They do not establish speech presence, intelligibility, background noise, speaker identity or microphone distance.',
      'Capture thresholds are provisional technical checks; they are not calibrated on children’s speech. A checked recording can still be unsuitable.',
      'Recognized sounds, sound differences, model confidence and accuracy are unavailable without an appropriate validated model.',
      ...(processingStatus === 'declined' ? ['The parent did not consent to optional automated analysis. No recognition model was called.'] : []),
      ...(processingStatus === 'failed' ? ['Recognition failed or timed out. Original audio remains available.'] : []),
      ...(processingStatus === 'unconfigured' ? ['No speech recognition service is configured. Original audio is available for therapist assessment.'] : []),
      ...(processingStatus === 'hosted_consent_required' ? ['External recognition was skipped because explicit parent permission for this provider is unavailable. Original audio is available for therapist assessment.'] : []),
      ...(processingStatus === 'quality_blocked' ? ['Recognition was skipped because capture checks could not support it. Listen to the original before requesting another recording.'] : []),
      ...(processingStatus === 'pending' ? ['Recognition is pending. Original audio has already been delivered.'] : []),
    ],
  };
}

async function recognitionWav(audio, signal, executable) {
  const quality = assessWordAudio(audio);
  if (!quality.eligibleForRecognition) throw new Error('Recording is not eligible for recognition');
  if (quality.sampleRate === 16000) return audio;
  return new Promise((resolve, reject) => {
    // An analysis copy is resampled in memory; patient originals stay intact.
    const process = spawn(executable, ['-nostdin', '-hide_banner', '-loglevel', 'error', '-f', 'wav', '-i', 'pipe:0', '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', '-f', 's16le', 'pipe:1'], { stdio: ['pipe', 'pipe', 'ignore'], signal });
    const chunks = [];
    let size = 0;
    process.on('error', () => reject(new Error('Local audio conversion unavailable')));
    process.stdout.on('data', chunk => {
      size += chunk.length;
      if (size > 2 * 1024 * 1024) { process.kill(); reject(new Error('Converted audio is too large')); }
      else chunks.push(chunk);
    });
    process.stdin.on('error', () => {});
    process.on('close', code => {
      if (code !== 0 || !size || size % 2) { reject(new Error('Local audio conversion failed')); return; }
      // Pipe WAV muxers cannot seek back to replace streaming length sentinels.
      // Wrap the bounded PCM output ourselves so downstream decoders receive
      // a complete RIFF file with exact format and data lengths.
      const header = Buffer.alloc(44);
      header.write('RIFF'); header.writeUInt32LE(36 + size, 4); header.write('WAVE', 8);
      header.write('fmt ', 12); header.writeUInt32LE(16, 16);
      header.writeUInt16LE(1, 20); header.writeUInt16LE(1, 22);
      header.writeUInt32LE(16000, 24); header.writeUInt32LE(32000, 28);
      header.writeUInt16LE(2, 32); header.writeUInt16LE(16, 34);
      header.write('data', 36); header.writeUInt32LE(size, 40);
      resolve(Buffer.concat([header, ...chunks]));
    });
    process.stdin.end(audio);
  });
}

export function createLocalTranscriber({ endpoint = process.env.SPEECH_ML_URL, model = process.env.SPEECH_ML_MODEL || 'local-whisper', language = process.env.SPEECH_ML_LANGUAGE || 'en', timeout = Number(process.env.SPEECH_ML_TIMEOUT_MS || 15000), ffmpeg = process.env.SPEECH_ML_FFMPEG_PATH || 'ffmpeg' } = {}) {
  if (!endpoint) return null;
  const url = new URL(endpoint);
  if (!['http:', 'https:'].includes(url.protocol) || !['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname) || url.username || url.password) throw new Error('Speech ML must use a loopback URL.');
  if (!Number.isFinite(timeout) || timeout < 100 || timeout > 120000) throw new Error('Speech ML timeout must be between 100 and 120000 milliseconds.');
  if (!/^[a-z]{2,3}$/.test(language) && language !== 'auto') throw new Error('Speech ML language must be an ISO language code or auto.');
  return {
    modelId: model, language, timeout,
    async suggest(audio, { signal } = {}) {
      const boundedSignal = signal ? AbortSignal.any([signal, AbortSignal.timeout(timeout)]) : AbortSignal.timeout(timeout);
      const analysisAudio = await recognitionWav(audio, boundedSignal, ffmpeg);
      const form = new FormData();
      form.set('file', new Blob([analysisAudio], { type: 'audio/wav' }), 'attempt.wav');
      form.set('temperature', '0.0');
      form.set('temperature_inc', '0.0');
      form.set('language', language);
      form.set('response_format', 'json');
      // No target word or previous transcript is provided: a recognizer primed
      // with the expected answer could appear correct without hearing it.
      const response = await fetch(url, { method: 'POST', body: form, redirect: 'error', signal: boundedSignal });
      if (!response.ok) throw new Error('Local speech recognition unavailable');
      const raw = await response.text();
      if (raw.length > 65536) throw new Error('Local recognition response too large');
      const payload = JSON.parse(raw);
      if (typeof payload.text !== 'string' || payload.text.length > 4000) throw new Error('Invalid recognition response');
      return payload.text.trim();
    },
  };
}

export function createHostedTranscriber({ apiKey = process.env.GROQ_API_KEY, model = process.env.SPEECH_ML_MODEL || 'whisper-large-v3', language = process.env.SPEECH_ML_LANGUAGE || 'en', timeout = Number(process.env.SPEECH_ML_TIMEOUT_MS || 15000), ffmpeg = process.env.SPEECH_ML_FFMPEG_PATH || 'ffmpeg', transport = fetch } = {}) {
  if (!apiKey?.trim()) return null;
  if (!['whisper-large-v3', 'whisper-large-v3-turbo'].includes(model)) throw new Error('Choose a supported Groq Whisper model.');
  if (!Number.isFinite(timeout) || timeout < 100 || timeout > 120000) throw new Error('Speech ML timeout must be between 100 and 120000 milliseconds.');
  if (!/^[a-z]{2}$/.test(language) && language !== 'auto') throw new Error('Hosted speech ML language must be a two-letter ISO language code or auto.');
  return {
    modelId: model, language, timeout, externalProvider: 'groq',
    async suggest(audio, { signal, canUseHosted } = {}) {
      const boundedSignal = signal ? AbortSignal.any([signal, AbortSignal.timeout(timeout)]) : AbortSignal.timeout(timeout);
      const analysisAudio = await recognitionWav(audio, boundedSignal, ffmpeg);
      const form = new FormData();
      form.set('file', new Blob([analysisAudio], { type: 'audio/wav' }), 'attempt.wav');
      form.set('model', model);
      if (language !== 'auto') form.set('language', language);
      form.set('temperature', '0');
      form.set('response_format', 'verbose_json');
      if (typeof canUseHosted !== 'function' || !await canUseHosted()) throw new Error('Hosted speech recognition permission is required');
      // No names, target answers or contextual prompt are sent. The child and
      // reference are recognized independently to avoid answer priming.
      const response = await transport('https://api.groq.com/openai/v1/audio/transcriptions', { method: 'POST', headers: { Authorization: `Bearer ${apiKey.trim()}` }, body: form, redirect: 'error', signal: boundedSignal });
      if (!response.ok) throw new Error('Hosted speech recognition unavailable');
      const raw = await response.text();
      if (raw.length > 65536) throw new Error('Hosted recognition response too large');
      const payload = JSON.parse(raw);
      if (typeof payload.text !== 'string' || payload.text.length > 4000) throw new Error('Invalid recognition response');
      const finite = value => typeof value === 'number' && Number.isFinite(value) ? value : null;
      const segments = Array.isArray(payload.segments) ? payload.segments.slice(0, 100).map(segment => ({
        start: finite(segment.start), end: finite(segment.end),
        averageLogProbability: finite(segment.avg_logprob), noSpeechProbability: finite(segment.no_speech_prob), compressionRatio: finite(segment.compression_ratio),
      })) : [];
      return {
        text: payload.text.trim(),
        evidence: { segments, warnings: [
          ...(segments.some(segment => segment.noSpeechProbability >= 0.6) ? ['Recognizer flagged possible non-speech. Listen before using the transcript.'] : []),
          ...(segments.some(segment => segment.averageLogProbability != null && segment.averageLogProbability < -1) ? ['Recognizer reported uncertain text. Listen before using the transcript.'] : []),
        ], interpretation: 'Whisper diagnostics are uncalibrated recognition evidence. They are not child pronunciation confidence or accuracy.' },
      };
    },
  };
}

export function createSpeechTranscriber({ provider = process.env.SPEECH_ML_PROVIDER || 'local', ...options } = {}) {
  if (provider === 'local') return createLocalTranscriber(options);
  if (provider === 'groq') return createHostedTranscriber(options);
  throw new Error('SPEECH_ML_PROVIDER must be local or groq.');
}

export async function recognizeWithDeadline(transcriber, audio, milliseconds = transcriber.timeout || 15000, options = {}) {
  let timer;
  const controller = new AbortController();
  try {
    return await Promise.race([
      Promise.resolve().then(() => transcriber.suggest(audio, { ...options, signal: controller.signal })),
      new Promise((_, reject) => { timer = setTimeout(() => { controller.abort(); reject(new Error('Recognition timed out')); }, milliseconds); timer.unref?.(); }),
    ]);
  } finally { clearTimeout(timer); controller.abort(); }
}
