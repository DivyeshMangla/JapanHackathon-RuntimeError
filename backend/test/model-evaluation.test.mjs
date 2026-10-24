import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { evaluateModels, wordErrors } from '../src/evaluate-models.mjs';

test('text error rate counts substitutions, deletions and insertions without inventing pronunciation accuracy', () => {
  assert.deepEqual(wordErrors('Water, please!', 'water please'), { errors: 0, referenceWords: 2, exact: true });
  assert.equal(wordErrors('water please', 'water').errors, 1);
  assert.equal(wordErrors('water', 'water now please').errors, 2);
  assert.equal(wordErrors('help', 'yes').errors, 1);
});

test('evaluation reports coverage and abstention alongside clinician rubric agreement', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'melo-model-evaluation-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  await writeFile(join(dir, 'photo.png'), Buffer.from('fixture'));
  await writeFile(join(dir, 'invalid.wav'), Buffer.from('malformed'));
  const report = await evaluateModels({ schemaVersion: 1,
    speech: [{ id: 'audio', audio: 'invalid.wav', reference: 'help' }],
    drawing: [{ id: 'clear', photo: 'photo.png', exerciseId: 'motor-lines', assessable: true, ratings: { alignment: 'consistent', formation: 'developing', spacing: 'consistent' } },
      { id: 'poor', photo: 'photo.png', exerciseId: 'motor-lines', assessable: false, ratings: { alignment: 'not_assessable', formation: 'not_assessable', spacing: 'not_assessable' } }],
  }, { baseDir: dir, analyzer: async () => ({ alignment: 'not_assessable', formation: 'not_assessable', spacing: 'not_assessable' }) });
  assert.equal(report.speech.captureBlocked, 1);
  assert.equal(report.speech.corpusWordErrorRate, null);
  assert.equal(report.drawing.completed, 2);
  assert.equal(report.drawing.abstained, 2);
  assert.equal(report.drawing.referenceUnassessable, 1);
  assert.equal(report.drawing.ratedDespiteUnassessableReference, 0);
  assert.deepEqual(report.drawing.categories.formation, { compared: 2, agreed: 1, abstained: 2 });
  assert.ok(!JSON.stringify(report).includes('photo.png'));
});

test('invalid labelled manifests fail before model calls', async () => {
  let calls = 0;
  await assert.rejects(evaluateModels({ schemaVersion: 1, speech: [], drawing: [{ id: 'x', photo: 'x', exerciseId: 'invented' }] }, { analyzer: async () => { calls++; } }), /Drawing samples/);
  await assert.rejects(evaluateModels({ schemaVersion: 1, speech: [], drawing: [{ id: 'x', photo: 'x', exerciseId: 'motor-lines', assessable: false, ratings: { alignment: 'consistent', formation: 'consistent', spacing: 'consistent' } }] }), /Unassessable drawing/);
  assert.equal(calls, 0);
});

test('hosted evaluation requires explicit permission before reading or sending labelled samples', async () => {
  let calls = 0;
  await assert.rejects(evaluateModels({schemaVersion:1,speech:[{id:'speech',audio:'not-read.wav',reference:'help'}],drawing:[]}, {
    transcriber: {externalProvider:'groq', suggest:async()=>{calls++;return {text:'help'};}},
  }), /allow-hosted-evaluation/);
  assert.equal(calls,0);
});
