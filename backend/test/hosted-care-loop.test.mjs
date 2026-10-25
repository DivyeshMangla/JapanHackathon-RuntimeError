import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/server.mjs';
import { newSession } from '../src/auth.mjs';
import { consentVersion, now } from '../src/db.mjs';
import { motorReference } from '../src/motor-reference.mjs';
import { motorExercises } from '../src/motor.mjs';
import { toneWav } from './fixtures/audio.mjs';

test('one scoped parent grant controls both hosted pipelines; rejected photos do not add completion', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'melo-hosted-loop-'));
  let speechCalls = 0, photoCalls = 0, rejectPhoto = true;
  const transcriber = { externalProvider: 'groq', modelId: 'test-whisper', suggest: async () => { speechCalls++; return { text: 'help' }; } };
  const analyzer = async () => {
    photoCalls++;
    return rejectPhoto
      ? { imageQuality: 'retake', retakeReason: 'unrelated_photo', observations: 'INTERNAL_SCENE_DETAILS', model: 'test-model' }
      : { imageQuality: 'usable', observations: 'INTERNAL_VISUAL_OBSERVATIONS', model: 'test-model' };
  };
  analyzer.externalProvider = 'groq';
  const app = createApp({ dataDir: dir, transcriber, motorAnalyzer: analyzer });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await Promise.all([app.motor.waitForIdle(), app.wordRoutes.waitForIdle()]);
    app.server.closeAllConnections();
    await new Promise(resolve => app.server.close(resolve));
    app.db.close();
    await rm(dir, { recursive: true, force: true });
  });
  const base = `http://127.0.0.1:${app.server.address().port}/api`;
  const add = role => {
    const id = randomUUID();
    app.db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES(?,?,?,?,?,?,?)')
      .run(id, `Synthetic ${role}`, `${id}@example.test`, 'unused', role, 'active', now());
    return { id, token: newSession(app.db, id) };
  };
  const therapist = add('therapist'), parent = add('parent'), child = add('patient');
  app.db.prepare('UPDATE users SET therapist_id=?,parent_id=? WHERE id=?').run(therapist.id, parent.id, child.id);
  app.db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES(?,?,?,?,?,?,?,?)')
    .run(randomUUID(), child.id, consentVersion, 'Synthetic guardian', 'fixture', JSON.stringify({ analysis: false }), 'approved', now());
  const call = async (user, path, method = 'GET', body) => {
    const response = await fetch(base + path, { method, headers: { Authorization: `Bearer ${user.token}`, ...(body ? { 'Content-Type': 'application/json' } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) });
    return { status: response.status, data: await response.json() };
  };
  const patientPath = `/patients/${child.id}`, wordPath = `/useful-words/patients/${child.id}`;
  const audio = toneWav().toString('base64');
  const word = await call(therapist, `${wordPath}/words`, 'POST', { word: 'help', picture: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB', exampleAudio: audio });
  assert.equal(word.status, 201);
  const sendWord = () => call(child, `${wordPath}/attempts`, 'POST', { id: randomUUID(), wordId: word.data.id, audio });
  const plan = await call(therapist, `${patientPath}/plans`, 'POST', { title: 'Synthetic drawing', exercises: ['motor-lines', 'motor-shapes'], sessionsPerDay: 1, notes: 'Synthetic plan' });
  assert.equal(plan.status, 201);
  const sendPhoto = async exerciseId => {
    const id = randomUUID();
    const result = await call(child, `${patientPath}/motor-submissions`, 'POST', { id, planId: plan.data.plan.id, exerciseId, practiceDay: new Date().toISOString().slice(0, 10), photo: motorReference(motorExercises.find(exercise => exercise.id === exerciseId)).toString('base64') });
    assert.equal(result.status, 201);
    await app.motor.waitForIdle();
    return id;
  };
  const permission = await call(parent, `${patientPath}/hosted-analysis`);
  assert.equal(permission.data.allowed, false);
  await sendWord(); await sendPhoto('motor-lines');
  await app.wordRoutes.waitForIdle();
  assert.equal(speechCalls, 0); assert.equal(photoCalls, 0);

  assert.equal((await call(parent, `${patientPath}/hosted-analysis`, 'PUT', { allowed: true, adultConfirmed: true, disclosureVersion: permission.data.disclosureVersion })).status, 200);
  assert.equal(JSON.parse(app.db.prepare('SELECT checks FROM consents WHERE patient_id=?').get(child.id).checks).analysis, false, 'the separate hosted grant must preserve the signed original');
  await sendWord(); await app.wordRoutes.waitForIdle();
  assert.equal(speechCalls, 2, 'child and frozen reference are independently transcribed');
  const rejectedId = await sendPhoto('motor-shapes');
  const rejected = await call(child, `/motor-submissions/${rejectedId}/status`);
  assert.equal(rejected.status, 200);
  assert.equal(rejected.data.captureFeedback.replacementRequired, true);
  assert.equal(rejected.data.captureFeedback.reason, 'unrelated_photo');
  assert.ok(!JSON.stringify(rejected.data).includes('INTERNAL_'));
  assert.equal(app.db.prepare('SELECT COUNT(*) n FROM progress WHERE patient_id=?').get(child.id).n, 1, 'only the earlier manually delivered practice is counted');
  rejectPhoto = false;
  await sendPhoto('motor-shapes');
  assert.equal(app.db.prepare('SELECT COUNT(*) n FROM progress WHERE patient_id=?').get(child.id).n, 2);
  rejectPhoto = true;
  await sendPhoto('motor-shapes');
  assert.equal(app.db.prepare('SELECT COUNT(*) n FROM progress WHERE patient_id=?').get(child.id).n, 2, 'another rejected photo cannot remove a valid same-day completion');
  const photoCallsBeforeRevocation = photoCalls;
  assert.equal((await call(parent, `${patientPath}/hosted-analysis`, 'PUT', { allowed: false })).status, 200);
  await sendWord(); await sendPhoto('motor-shapes');
  await app.wordRoutes.waitForIdle();
  assert.equal(speechCalls, 2); assert.equal(photoCalls, photoCallsBeforeRevocation);
});
