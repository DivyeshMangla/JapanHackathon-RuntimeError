import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/server.mjs';
import { newSession } from '../src/auth.mjs';
import { now, consentVersion } from '../src/db.mjs';
import { hostedAnalysisDisclosureVersion } from '../src/hosted-analysis.mjs';
import { drawingPhoto } from './fixtures/motor-photos.mjs';

const usable = { imageQuality: 'usable', observations: 'Three visible lines.', model: 'synthetic-test' };
const unrelated = { imageQuality: 'retake', qualityFlags: ['unrelated'], retakeReason: 'unrelated_photo', observations: 'PRIVATE MODEL DESCRIPTION', model: 'synthetic-test' };

async function fixture(t, analyzer) {
  const dir = await mkdtemp(join(tmpdir(), 'melo-motor-capture-'));
  const app = createApp({ dataDir: dir, motorAnalyzer: analyzer });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await app.motor.waitForIdle(); app.server.closeAllConnections();
    await new Promise(resolve => app.server.close(resolve)); app.db.close();
    await rm(dir, { recursive: true, force: true });
  });
  const add = role => {
    const id = randomUUID();
    app.db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES(?,?,?,?,?,?,?)').run(id, 'Synthetic Test', `${id}@test.example`, 'not-a-real-password', role, 'active', now());
    return { id, token: newSession(app.db, id) };
  };
  const parent = add('parent'), therapist = add('therapist'), child = add('patient'), stranger = add('patient');
  app.db.prepare('UPDATE users SET therapist_id=?,parent_id=? WHERE id=?').run(therapist.id, parent.id, child.id);
  const consentId = randomUUID(), planId = randomUUID();
  app.db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES(?,?,?,?,?,?,?,?)').run(consentId, child.id, consentVersion, 'Synthetic Guardian', 'synthetic-signature', JSON.stringify({ analysis: true }), 'approved', now());
  app.db.prepare('INSERT INTO plans VALUES(?,?,?,?,?,?,?,?,?)').run(planId, child.id, therapist.id, consentId, 'Synthetic drawing plan', JSON.stringify(['motor-lines']), 1, '', now());
  const call = async (path, method = 'GET', value, token = child.token) => {
    const response = await fetch(`http://127.0.0.1:${app.server.address().port}/api${path}`, {
      method, headers: { Authorization: `Bearer ${token}`, ...(value ? { 'Content-Type': 'application/json' } : {}) }, body: value ? JSON.stringify(value) : undefined,
    });
    const body = response.headers.get('content-type')?.startsWith('application/json') ? await response.json() : Buffer.from(await response.arrayBuffer());
    return { status: response.status, body };
  };
  const upload = (id = randomUUID()) => ({ id, planId, exerciseId: 'motor-lines', practiceDay: now().slice(0, 10), photo: drawingPhoto().toString('base64') });
  const grant = allowed => app.db.prepare("INSERT INTO hosted_analysis_permissions VALUES(?,'groq',?,?,?,?) ON CONFLICT(patient_id,provider) DO UPDATE SET allowed=excluded.allowed").run(child.id, parent.id, Number(allowed), hostedAnalysisDisclosureVersion(), now());
  return { ...app, child, therapist, parent, stranger, call, upload, grant, path: `/patients/${child.id}` };
}

test('rejected photo is visible to therapist, requests family reupload and does not complete practice; valid replacement counts once', async t => {
  let report = unrelated;
  const f = await fixture(t, async () => report);
  const first = f.upload();
  assert.equal((await f.call(`${f.path}/motor-submissions`, 'POST', first)).status, 201);
  await f.motor.waitForIdle();
  const status = await f.call(`/motor-submissions/${first.id}/status`);
  assert.equal(status.body.captureFeedback.reason, 'unrelated_photo');
  assert.equal(status.body.countsAsPractice, false);
  assert.ok(!JSON.stringify(status.body).includes('PRIVATE MODEL DESCRIPTION'));
  assert.equal((await f.call(f.path)).body.patient.sessions, 0);
  assert.equal((await f.call(`${f.path}/family-progress`, 'GET', undefined, f.parent.token)).body.activities.find(activity => activity.kind === 'drawing').attempts, 0);
  assert.equal((await f.call(`/motor-submissions/${first.id}/photo`, 'GET', undefined, f.therapist.token)).body.equals(drawingPhoto()), true);
  assert.equal((await f.call(`/motor-submissions/${first.id}/status`, 'GET', undefined, f.stranger.token)).status, 403);
  const familyRow = (await f.call(f.path, 'GET', undefined, f.parent.token)).body.motorSubmissions[0];
  assert.equal(familyRow.report, null);
  assert.equal(familyRow.captureFeedback.replacementRequired, true);
  report = usable;
  const replacement = f.upload();
  await f.call(`${f.path}/motor-submissions`, 'POST', replacement);
  await f.motor.waitForIdle();
  assert.equal((await f.call(f.path)).body.patient.sessions, 1);
  assert.equal((await f.call(f.path)).body.patient.active_days, 1);
  assert.equal((await f.call(`${f.path}/motor-submissions`, 'POST', replacement)).status, 200);
  await f.motor.waitForIdle();
  assert.equal((await f.call(f.path)).body.progress.length, 1);
});

test('an unrelated extra photo cannot erase a valid same-day practice completion', async t => {
  let report = usable;
  const f = await fixture(t, async () => report);
  await f.call(`${f.path}/motor-submissions`, 'POST', f.upload());
  await f.motor.waitForIdle();
  report = unrelated;
  await f.call(`${f.path}/motor-submissions`, 'POST', f.upload());
  await f.motor.waitForIdle();
  const record = (await f.call(f.path)).body;
  assert.equal(record.patient.sessions, 1);
  assert.equal(record.progress.length, 1);
  assert.equal(f.motor.familyProgressSnapshot(f.child.id).length, 1);
});

test('provider failure retains original upload and completion for manual review', async t => {
  const f = await fixture(t, async () => { throw new Error('Synthetic rate limit'); });
  const upload = f.upload();
  assert.equal((await f.call(`${f.path}/motor-submissions`, 'POST', upload)).status, 201);
  await f.motor.waitForIdle();
  const status = (await f.call(`/motor-submissions/${upload.id}/status`)).body;
  assert.equal(status.analysisStatus, 'unavailable');
  assert.equal(status.captureFeedback, null);
  assert.equal(status.countsAsPractice, true);
  assert.equal((await f.call(f.path)).body.patient.sessions, 1);
  assert.equal((await f.call(`/motor-submissions/${upload.id}/photo`, 'GET', undefined, f.therapist.token)).body.equals(drawingPhoto()), true);
});

test('hosted photo queue requires separate current permission even if original local analysis was allowed', async t => {
  let calls = 0;
  const analyzer = async () => { calls++; return usable; };
  analyzer.externalProvider = 'groq';
  const f = await fixture(t, analyzer);
  await f.call(`${f.path}/motor-submissions`, 'POST', f.upload());
  await f.motor.waitForIdle();
  assert.equal(calls, 0);
  f.grant(true);
  // The separate online opt-in can be granted even when original local analysis
  // was declined; signed care consent is deliberately left unchanged.
  f.db.prepare('UPDATE consents SET checks=? WHERE patient_id=?').run(JSON.stringify({ analysis: false }), f.child.id);
  await f.call(`${f.path}/motor-submissions`, 'POST', f.upload());
  await f.motor.waitForIdle();
  assert.equal(calls, 1);
  f.grant(false);
  await f.call(`${f.path}/motor-submissions`, 'POST', f.upload());
  await f.motor.waitForIdle();
  assert.equal(calls, 1);
});

test('permission withdrawal while first photo is running prevents a queued hosted photo request', async t => {
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  let calls = 0;
  const analyzer = async (_photo, _exercise, context) => {
    calls++; await gate;
    if (!await context.canUseHosted()) throw new Error('Permission withdrawn');
    return usable;
  };
  analyzer.externalProvider = 'groq';
  const f = await fixture(t, analyzer);
  f.grant(true);
  await f.call(`${f.path}/motor-submissions`, 'POST', f.upload());
  await f.call(`${f.path}/motor-submissions`, 'POST', f.upload());
  f.grant(false); release(); await f.motor.waitForIdle();
  assert.equal(calls, 1);
  assert.ok(f.motor.summaries(f.child.id, 'therapist').every(row => row.analysis_status === 'declined'));
  assert.equal((await f.call(f.path)).body.progress.length, 1);
});
