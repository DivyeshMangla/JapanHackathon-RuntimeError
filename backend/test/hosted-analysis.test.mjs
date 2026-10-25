import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { hostedAnalysis, hostedAnalysisDisclosureVersion } from '../src/hosted-analysis.mjs';

function fixture(file = ':memory:', provider = 'groq') {
  const db = new DatabaseSync(file);
  db.exec(`
    CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY,role TEXT,status TEXT,parent_id TEXT,therapist_id TEXT);
    CREATE TABLE IF NOT EXISTS consents(id TEXT PRIMARY KEY,patient_id TEXT,status TEXT,checks TEXT,signed_at TEXT);
    INSERT OR IGNORE INTO users VALUES ('parent','parent','active',NULL,NULL);
    INSERT OR IGNORE INTO users VALUES ('other-parent','parent','active',NULL,NULL);
    INSERT OR IGNORE INTO users VALUES ('therapist','therapist','active',NULL,NULL);
    INSERT OR IGNORE INTO users VALUES ('other-therapist','therapist','active',NULL,NULL);
    INSERT OR IGNORE INTO users VALUES ('child','patient','active','parent','therapist');
    INSERT OR IGNORE INTO users VALUES ('other-child','patient','active','other-parent','other-therapist');
    INSERT OR IGNORE INTO users VALUES ('admin','admin','active',NULL,NULL);
    INSERT OR IGNORE INTO consents VALUES ('consent','child','approved','{"analysis":false}','2026-10-25T10:00:00Z');
  `);
  const fail = (status, message) => { throw Object.assign(new Error(message), { status }); };
  const find = id => db.prepare('SELECT * FROM users WHERE id=?').get(id);
  let response;
  const api = hostedAnalysis({
    provider, db, fail, body: async req => req.value,
    json: (_, status, value) => { response = { status, value }; },
    requireRole: (u, ...roles) => { if (!roles.includes(u.role)) fail(403, 'Role denied'); },
    accessPatient: (u, id) => {
      const child = find(id);
      if (child?.role !== 'patient') fail(404, 'Unknown child');
      if (u.role !== 'admin' && u.id !== child.id
          && !(u.role === 'parent' && child.parent_id === u.id)
          && !(u.role === 'therapist' && child.therapist_id === u.id)) fail(403, 'Not paired');
      return child;
    },
  });
  const call = async (actor = 'parent', method = 'GET', value, patientId = 'child') => {
    await api.handle({ method, value }, {}, `/api/patients/${patientId}/hosted-analysis`, find(actor));
    return response;
  };
  const grant = (overrides = {}) => call('parent', 'PUT', {
    allowed: true, adultConfirmed: true, disclosureVersion: hostedAnalysisDisclosureVersion(provider), ...overrides,
  });
  return { db, api, find, call, grant };
}

test('existing care consent never silently opts a child in to hosted processing', async t => {
  const f = fixture(); t.after(() => f.db.close());
  assert.equal(f.api.allowed('child'), false);
  let result = (await f.call()).value;
  assert.equal(result.allowed, false);
  assert.equal(result.careConsentApproved, true);
  assert.equal(result.localAnalysisAllowed, false);
  assert.equal(result.analysisAllowed, false);
  assert.equal(result.updatedAt, null);
  f.db.prepare('UPDATE consents SET checks=?').run(JSON.stringify({ analysis: true }));
  result = (await f.call()).value;
  assert.equal(result.localAnalysisAllowed, true);
  assert.equal(result.analysisAllowed, true);
  assert.equal(result.allowed, false);
  assert.equal(f.api.allowed('child'), false, 'the earlier local-analysis checkbox does not authorize an external provider');
  assert.equal(f.api.allowed('unknown'), false);
  assert.equal(f.api.allowed('child', 'another-provider'), false);
});

test('a new scoped parent grant can permit hosted analysis without changing a signed local-analysis refusal', async t => {
  const f = fixture(); t.after(() => f.db.close());
  const original = f.db.prepare('SELECT * FROM consents').get();
  const result = await f.grant();
  assert.equal(result.status, 200);
  assert.equal(result.value.allowed, true);
  assert.equal(result.value.analysisAllowed, true);
  assert.equal(result.value.localAnalysisAllowed, false);
  assert.equal(f.api.allowed('child', 'groq'), true);
  assert.deepEqual(f.db.prepare('SELECT * FROM consents').get(), original);
  assert.equal(f.db.prepare('SELECT COUNT(*) AS count FROM hosted_analysis_permission_events').get().count, 1);
  const disclosure = result.value.disclosure.text;
  for (const detail of ['Groq', 'United States', '30 days', 'reference recording', 'turn off', 'separate, optional permission']) assert.ok(disclosure.includes(detail));
});

test('only the paired parent may change permission and only the parent or current active therapist may read it', async t => {
  const f = fixture(); t.after(() => f.db.close());
  for (const id of ['parent', 'therapist']) assert.equal((await f.call(id)).status, 200);
  for (const id of ['other-parent', 'other-therapist', 'child', 'other-child', 'admin']) {
    await assert.rejects(f.call(id), { status: 403 });
    await assert.rejects(f.call(id, 'PUT', { allowed: false }), { status: 403 });
  }
  await assert.rejects(f.call('therapist', 'PUT', { allowed: false }), { status: 403 });
  await assert.rejects(f.call('parent', 'GET', undefined, 'other-child'), { status: 403 });
  await assert.rejects(f.call('parent', 'GET', undefined, 'unknown'), { status: 404 });
  await assert.rejects(f.call('parent', 'POST', {}), { status: 405 });
  f.db.prepare("UPDATE users SET status='disabled' WHERE id='therapist'").run();
  await assert.rejects(f.call('therapist'), { status: 403 });
  assert.equal(await f.api.handle({ method: 'GET' }, {}, '/api/config', f.find('parent')), false);
  assert.equal(f.db.prepare('SELECT COUNT(*) AS count FROM hosted_analysis_permission_events').get().count, 0);
});

test('a grant requires current disclosure, explicit guardian confirmation and approved care', async t => {
  const f = fixture(); t.after(() => f.db.close());
  await assert.rejects(f.grant({ disclosureVersion: 'old' }), { status: 409 });
  await assert.rejects(f.grant({ adultConfirmed: false }), { status: 400 });
  await assert.rejects(f.grant({ allowed: 'true' }), { status: 400 });
  f.db.prepare("UPDATE consents SET status='pending'").run();
  await assert.rejects(f.grant(), { status: 409 });
  assert.equal(f.api.allowed('child'), false);
  assert.equal(f.db.prepare('SELECT COUNT(*) AS count FROM hosted_analysis_permission_events').get().count, 0);
});

test('revoking hosted permission is immediate, accepts stale wording, and preserves local permission', async t => {
  const f = fixture(); t.after(() => f.db.close());
  f.db.prepare('UPDATE consents SET checks=?').run(JSON.stringify({ analysis: true }));
  await f.grant();
  const result = await f.call('parent', 'PUT', { allowed: false, disclosureVersion: 'old' });
  assert.equal(result.value.allowed, false);
  assert.equal(result.value.localAnalysisAllowed, true);
  assert.equal(result.value.analysisAllowed, true);
  assert.equal(f.api.allowed('child'), false);
  assert.deepEqual(f.db.prepare('SELECT allowed FROM hosted_analysis_permission_events ORDER BY seq').all().map(x => x.allowed), [1, 0]);
});

test('runtime permission rechecks care status, parent changes, parent account state and disclosure changes', async t => {
  const f = fixture(); t.after(() => f.db.close());
  await f.grant();
  f.db.prepare("UPDATE consents SET status='withdrawn'").run();
  assert.equal(f.api.allowed('child'), false);
  f.db.prepare("UPDATE consents SET status='approved'").run();
  assert.equal(f.api.allowed('child'), true);
  f.db.prepare("UPDATE users SET parent_id='other-parent' WHERE id='child'").run();
  assert.equal(f.api.allowed('child'), false);
  f.db.prepare("UPDATE users SET parent_id='parent' WHERE id='child'").run();
  f.db.prepare("UPDATE users SET status='disabled' WHERE id='parent'").run();
  assert.equal(f.api.allowed('child'), false);
  f.db.prepare("UPDATE users SET status='active' WHERE id='parent'").run();
  f.db.prepare("UPDATE users SET status='disabled' WHERE id='child'").run();
  assert.equal(f.api.allowed('child'), false);
  f.db.prepare("UPDATE users SET status='active' WHERE id='child'").run();
  f.db.prepare("UPDATE hosted_analysis_permissions SET disclosure_version='outdated'").run();
  assert.equal(f.api.allowed('child'), false);
});

test('grants and revocations survive reopening without storing media, names or account profiles', async t => {
  const dir = mkdtempSync(join(tmpdir(), 'melo-hosted-permission-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const file = join(dir, 'permission.sqlite');
  let f = fixture(file);
  await f.grant();
  f.db.close();
  f = fixture(file);
  assert.equal(f.api.allowed('child'), true);
  await f.call('parent', 'PUT', { allowed: false });
  f.db.close();
  f = fixture(file);
  assert.equal(f.api.allowed('child'), false);
  const keys = Object.keys(f.db.prepare('SELECT * FROM hosted_analysis_permissions').get());
  assert.deepEqual(keys, ['patient_id', 'provider', 'parent_id', 'allowed', 'disclosure_version', 'updated_at']);
  assert.equal(f.db.prepare('SELECT COUNT(*) AS count FROM hosted_analysis_permission_events').get().count, 2);
  f.db.close();
});

test('a Gemini deployment asks for its own grant and never accepts a Groq grant', async t => {
  const dir = mkdtempSync(join(tmpdir(), 'melo-hosted-')), file = join(dir, 'care.sqlite');
  const groq = fixture(file);
  assert.equal((await groq.grant()).value.allowed, true);
  groq.db.close();
  const gemini = fixture(file, 'gemini');
  t.after(() => { gemini.db.close(); rmSync(dir, { force: true, recursive: true, maxRetries: 3 }); });
  const before = (await gemini.call()).value;
  assert.equal(before.provider, 'gemini');
  assert.equal(before.allowed, false);
  assert.ok(before.disclosure.text.includes('Gemini API'));
  assert.equal(gemini.api.allowed('child', 'groq'), false);
  assert.equal(gemini.api.allowed('child', 'gemini'), false);
  await assert.rejects(gemini.grant({ disclosureVersion: hostedAnalysisDisclosureVersion('groq') }), { status: 409 });
  assert.equal((await gemini.grant()).value.allowed, true);
  assert.equal(gemini.api.allowed('child', 'gemini'), true);
  assert.deepEqual(gemini.db.prepare('SELECT provider FROM hosted_analysis_permissions ORDER BY provider').all().map(row => row.provider), ['gemini', 'groq']);
});

test('tables created when only Groq was accepted are migrated without losing grants', async t => {
  const db = new DatabaseSync(':memory:');
  t.after(() => db.close());
  db.exec(`CREATE TABLE hosted_analysis_permissions (patient_id TEXT NOT NULL, provider TEXT NOT NULL CHECK(provider='groq'), parent_id TEXT NOT NULL,
      allowed INTEGER NOT NULL CHECK(allowed IN (0,1)), disclosure_version TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(patient_id,provider));
    CREATE TABLE hosted_analysis_permission_events (seq INTEGER PRIMARY KEY AUTOINCREMENT, patient_id TEXT NOT NULL, provider TEXT NOT NULL CHECK(provider='groq'),
      parent_id TEXT NOT NULL, allowed INTEGER NOT NULL CHECK(allowed IN (0,1)), disclosure_version TEXT NOT NULL, updated_at TEXT NOT NULL);
    INSERT INTO hosted_analysis_permissions VALUES ('child','groq','parent',1,'v','2026-10-25T10:00:00Z');
    INSERT INTO hosted_analysis_permission_events(patient_id,provider,parent_id,allowed,disclosure_version,updated_at) VALUES ('child','groq','parent',1,'v','2026-10-25T10:00:00Z');`);
  hostedAnalysis({ db, provider: 'gemini', fail: () => {}, body: async () => ({}), json: () => {}, requireRole: () => {}, accessPatient: () => {} });
  db.prepare("INSERT INTO hosted_analysis_permissions VALUES ('child','gemini','parent',1,'v','2026-10-25T11:00:00Z')").run();
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM hosted_analysis_permissions').get().count, 2);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM hosted_analysis_permission_events').get().count, 1);
  assert.throws(() => db.prepare("INSERT INTO hosted_analysis_permissions VALUES ('child','other','parent',1,'v','x')").run());
});
