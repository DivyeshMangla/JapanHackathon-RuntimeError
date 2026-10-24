import { readFile, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createMotorAnalyzer, motorExercises } from './motor.mjs';
import { assessWordAudio, createSpeechTranscriber, recognizeWithDeadline } from './pronunciation-report.mjs';

const categories = ['alignment', 'formation', 'spacing'];
const ratings = ['not_assessable', 'emerging', 'developing', 'consistent'];
const normalize = text => text.normalize('NFKC').toLowerCase().replace(/[\p{P}\p{S}]/gu, ' ').trim().split(/\s+/u).filter(Boolean);

// Corpus word error rate describes transcription, never pronunciation quality.
export function wordErrors(reference, hypothesis) {
  const expected = normalize(reference), actual = normalize(hypothesis);
  let previous = Array.from({ length: actual.length + 1 }, (_, i) => i);
  for (let i = 1; i <= expected.length; i++) {
    const row = [i];
    for (let j = 1; j <= actual.length; j++) row[j] = Math.min(row[j - 1] + 1, previous[j] + 1, previous[j - 1] + Number(expected[i - 1] !== actual[j - 1]));
    previous = row;
  }
  return { errors: previous[actual.length], referenceWords: expected.length, exact: expected.join(' ') === actual.join(' ') };
}

function validateManifest(manifest) {
  if (!manifest || manifest.schemaVersion !== 1 || !Array.isArray(manifest.speech) || !Array.isArray(manifest.drawing) || manifest.speech.length + manifest.drawing.length < 1 || manifest.speech.length + manifest.drawing.length > 1000) throw new Error('Provide schemaVersion 1 and speech/drawing arrays containing 1–1000 labelled samples.');
  const ids = new Set();
  for (const [kind, samples] of [['speech', manifest.speech], ['drawing', manifest.drawing]]) {
    for (const sample of samples) {
      if (!sample || typeof sample.id !== 'string' || !sample.id || ids.has(sample.id)) throw new Error('Every evaluation sample needs a unique ID.');
      ids.add(sample.id);
      if (typeof sample[kind === 'speech' ? 'audio' : 'photo'] !== 'string' || !sample[kind === 'speech' ? 'audio' : 'photo']) throw new Error('Every evaluation sample needs a local media path.');
      if (kind === 'speech' && (typeof sample.reference !== 'string' || !normalize(sample.reference).length)) throw new Error('Speech samples need a nonempty reference transcript.');
      if (kind === 'drawing' && (!motorExercises.some(exercise => exercise.id === sample.exerciseId) || typeof sample.assessable !== 'boolean' || !sample.ratings || !categories.every(category => ratings.includes(sample.ratings[category])))) throw new Error('Drawing samples need an exercise ID, assessable flag and clinician labels for alignment/formation/spacing.');
      if (kind === 'drawing' && !sample.assessable && categories.some(category => sample.ratings[category] !== 'not_assessable')) throw new Error('Unassessable drawing references must label every category not_assessable.');
    }
  }
}

export async function evaluateModels(manifest, { baseDir = '.', transcriber = null, analyzer = createMotorAnalyzer(), allowHosted = false } = {}) {
  validateManifest(manifest);
  if ((transcriber?.externalProvider || analyzer.externalProvider) && !allowHosted) throw new Error('Hosted evaluation would send supplied media to an external provider. Pass --allow-hosted-evaluation only for a dataset you are authorised to send.');
  const speech = { samples: manifest.speech.length, completed: 0, captureBlocked: 0, unavailable: 0, wordErrors: 0, referenceWords: 0, exactTextMatches: 0 };
  for (const sample of manifest.speech) {
    try {
      const audio = await readFile(resolve(baseDir, sample.audio));
      if (!assessWordAudio(audio).eligibleForRecognition) { speech.captureBlocked++; continue; }
      if (!transcriber) { speech.unavailable++; continue; }
      const recognition = await recognizeWithDeadline(transcriber, audio, undefined, {canUseHosted:()=>allowHosted});
      const transcript = typeof recognition === 'string' ? recognition : recognition?.text;
      if (typeof transcript !== 'string') throw new Error('Invalid transcript');
      const comparison = wordErrors(sample.reference, transcript);
      speech.completed++; speech.wordErrors += comparison.errors; speech.referenceWords += comparison.referenceWords;
      if (comparison.exact) speech.exactTextMatches++;
    } catch { speech.unavailable++; }
  }
  const drawing = { samples: manifest.drawing.length, completed: 0, unavailable: 0, abstained: 0, referenceUnassessable: 0, ratedDespiteUnassessableReference: 0, categories: Object.fromEntries(categories.map(category => [category, { compared: 0, agreed: 0, abstained: 0 }])) };
  for (const sample of manifest.drawing) {
    if (!sample.assessable) drawing.referenceUnassessable++;
    try {
      const report = await analyzer(await readFile(resolve(baseDir, sample.photo)), motorExercises.find(exercise => exercise.id === sample.exerciseId), { canUseHosted: () => allowHosted });
      if (!report || !categories.every(category => ratings.includes(report[category]))) throw new Error('Invalid drawing report');
      drawing.completed++;
      const rated = categories.some(category => report[category] !== 'not_assessable');
      if (!rated) drawing.abstained++;
      if (!sample.assessable && rated) drawing.ratedDespiteUnassessableReference++;
      for (const category of categories) {
        const metric = drawing.categories[category];
        if (report[category] === 'not_assessable') metric.abstained++;
        metric.compared++;
        if (report[category] === sample.ratings[category]) metric.agreed++;
      }
    } catch { drawing.unavailable++; }
  }
  return {
    schemaVersion: 1, generatedAt: new Date().toISOString(),
    speechModel: transcriber?.modelId || null,
    drawingModel: process.env.MOTOR_ML_MODEL || (process.env.MOTOR_ML_PROVIDER === 'groq' ? 'qwen/qwen3.8-27b' : 'gemma3:4b'),
    drawingRubric: 'visible-drawing-v3',
    speech: { ...speech, corpusWordErrorRate: speech.referenceWords ? speech.wordErrors / speech.referenceWords : null,
      tokenizer: 'NFKC lowercase, punctuation/symbols replaced with spaces, whitespace-delimited tokens' },
    drawing,
    interpretation: [
      'This evaluation uses the supplied labels only; it is not a clinical validation certificate.',
      'Word error rate measures recognized text, not pronunciation accuracy; it may exceed 1 for many inserted words.',
      'Whitespace tokenization is not a language-aware word segmenter. Use a reviewed language-specific evaluation for unsegmented scripts.',
      'Always report coverage, unavailable samples and abstentions alongside agreement.',
      'Category agreement includes not_assessable matches. Inspect unassessable-reference ratings separately.',
      'Use an independent, representative clinician-labelled holdout set spanning age, language, speech characteristics and image quality before selecting a model.',
    ],
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const args = process.argv.slice(2).filter(value => value !== '--allow-hosted-evaluation');
    const allowHosted = process.argv.includes('--allow-hosted-evaluation');
    const manifestPath = args[0];
    if (!manifestPath) throw new Error('Usage: node src/evaluate-models.mjs manifest.json [metrics.json]');
    const manifest = JSON.parse(await readFile(resolve(manifestPath), 'utf8'));
    const report = await evaluateModels(manifest, { baseDir: dirname(resolve(manifestPath)), transcriber: createSpeechTranscriber(), allowHosted });
    const output = JSON.stringify(report, null, 2) + '\n';
    if (args[1]) await writeFile(resolve(args[1]), output, { mode: 0o600, flag: 'wx' });
    else process.stdout.write(output);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
