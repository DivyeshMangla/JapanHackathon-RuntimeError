import { createHash } from 'node:crypto';

export const hostedAnalysisDisclosures = {
  groq: {
    title: 'Optional online analysis',
    provider: 'Groq',
    processingLocation: 'United States',
    text: 'I am this child’s parent or guardian and choose optional automated online analysis of their practice. The service sends the child’s practice photo or voice recording, the exercise target, and, when needed for comparison, the therapist’s reference recording to Groq in the United States. It does not send the child’s account name or profile. Automated observations and speech comparisons may be wrong and are for therapist review, not diagnosis or a validated pronunciation score. Groq may retain inputs and outputs for up to 30 days for reliability and abuse monitoring unless the service operator has enabled zero data retention. Practice and therapist feedback are still available without this permission. I can turn off future online requests here; turning this off cannot recall data already processed. This is a separate, optional permission and does not change the care consent already signed.',
    privacyUrl: 'https://console.groq.com/docs/your-data',
  },
  gemini: {
    title: 'Optional online analysis',
    provider: 'Google (Gemini API)',
    processingLocation: 'Google data centres; the region is not guaranteed',
    text: 'I am this child’s parent or guardian and choose optional automated online analysis of their practice. The service sends the child’s practice photo or voice recording, the exercise target and, when needed for comparison, the prescribed reference picture or the therapist’s reference recording to Google’s Gemini API. It does not send the child’s account name or profile. Automated observations and speech comparisons may be wrong and are for therapist review, not diagnosis, a drawing score or a validated pronunciation score. Google processes inputs and outputs under the Gemini API terms and may keep them for a limited time to detect abuse. Practice and therapist feedback are still available without this permission. I can turn off future online requests here; turning this off cannot recall data already processed. This is a separate, optional permission and does not change the care consent already signed.',
    privacyUrl: 'https://ai.google.dev/gemini-api/terms',
  },
};

// A disclosure change invalidates an earlier grant until the parent sees and
// explicitly accepts the new wording. No child's media or names are stored here.
export const hostedAnalysisDisclosureVersion = (provider = 'groq') => `${provider}-${createHash('sha256')
  .update(JSON.stringify(hostedAnalysisDisclosures[provider])).digest('hex').slice(0, 20)}`;

// Earlier databases only accepted Groq grants; rebuild those tables so a
// grant for another provider can be stored beside them.
function migrateProviderCheck(db) {
  const legacyCheck = "CHECK(provider='groq')";
  for (const table of ['hosted_analysis_permissions', 'hosted_analysis_permission_events']) {
    const sql = db.prepare("SELECT sql FROM sqlite_master WHERE type='table' AND name=?").get(table)?.sql;
    if (!sql?.includes(legacyCheck)) continue;
    db.exec('BEGIN');
    try {
      db.exec(`ALTER TABLE ${table} RENAME TO ${table}_legacy;
        ${sql.replace(legacyCheck, "CHECK(provider IN ('groq','gemini'))")};
        INSERT INTO ${table} SELECT * FROM ${table}_legacy;
        DROP TABLE ${table}_legacy;`);
      db.exec('COMMIT');
    } catch (error) { db.exec('ROLLBACK'); throw error; }
  }
}

// One online provider serves a deployment. A grant names the provider whose
// wording the parent accepted, so it never authorizes a different provider.
export function hostedAnalysis({ db, body, fail, json, accessPatient, requireRole, provider = 'groq' }) {
  const disclosure = hostedAnalysisDisclosures[provider];
  if (!disclosure) throw new Error('Online analysis provider must be groq or gemini.');
  const disclosureVersion = hostedAnalysisDisclosureVersion(provider);
  migrateProviderCheck(db);
  db.exec(`
    CREATE TABLE IF NOT EXISTS hosted_analysis_permissions (
      patient_id TEXT NOT NULL REFERENCES users(id),
      provider TEXT NOT NULL CHECK(provider IN ('groq','gemini')),
      parent_id TEXT NOT NULL REFERENCES users(id),
      allowed INTEGER NOT NULL CHECK(allowed IN (0,1)),
      disclosure_version TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY(patient_id,provider)
    );
    CREATE TABLE IF NOT EXISTS hosted_analysis_permission_events (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id TEXT NOT NULL REFERENCES users(id),
      provider TEXT NOT NULL CHECK(provider IN ('groq','gemini')),
      parent_id TEXT NOT NULL REFERENCES users(id),
      allowed INTEGER NOT NULL CHECK(allowed IN (0,1)),
      disclosure_version TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  const care = patientId => {
    const consent = db.prepare('SELECT status,checks FROM consents WHERE patient_id=? ORDER BY signed_at DESC,rowid DESC LIMIT 1').get(patientId);
    let checks = {};
    try { checks = JSON.parse(consent?.checks || '{}'); } catch { /* Invalid historical records do not grant permission. */ }
    const approved = consent?.status === 'approved';
    return { approved, localAnalysisAllowed: approved && checks?.analysis === true };
  };
  const record = patientId => db.prepare('SELECT * FROM hosted_analysis_permissions WHERE patient_id=? AND provider=?').get(patientId, provider);
  const allowed = (patientId, requested = provider) => {
    if (requested !== provider || !care(patientId).approved) return false;
    const permission = record(patientId);
    if (!permission || permission.allowed !== 1 || permission.disclosure_version !== disclosureVersion) return false;
    const child = db.prepare('SELECT role,status,parent_id FROM users WHERE id=?').get(patientId);
    if (child?.role !== 'patient' || child.status !== 'active' || child.parent_id !== permission.parent_id) return false;
    const parent = db.prepare('SELECT role,status FROM users WHERE id=?').get(permission.parent_id);
    return parent?.role === 'parent' && parent.status === 'active';
  };
  const snapshot = patientId => {
    const permission = record(patientId);
    const original = care(patientId);
    const granted = allowed(patientId);
    return {
      provider,
      allowed: granted,
      careConsentApproved: original.approved,
      localAnalysisAllowed: original.localAnalysisAllowed,
      analysisAllowed: original.localAnalysisAllowed || granted,
      disclosureVersion,
      disclosure,
      updatedAt: permission?.updated_at || null,
    };
  };

  const handle = async (req, res, path, user) => {
    const match = path.match(/^\/api\/patients\/([^/]+)\/hosted-analysis$/);
    if (!match) return false;
    const patientId = match[1];
    const child = accessPatient(user, patientId);
    requireRole(user, 'parent', 'therapist');
    if (user.status !== 'active') fail(403, 'This account is not active.');
    if (req.method === 'GET') {
      json(res, 200, snapshot(patientId));
      return true;
    }
    if (req.method !== 'PUT') fail(405, 'Method not allowed.');
    requireRole(user, 'parent');
    if (child.parent_id !== user.id) fail(403, 'Only this child’s parent can change online analysis permission.');
    const value = await body(req);
    if (typeof value.allowed !== 'boolean') fail(400, 'Choose whether to allow online analysis.');
    if (value.allowed) {
      if (!care(patientId).approved) fail(409, 'Approved care consent is required before optional online analysis.');
      if (value.disclosureVersion !== disclosureVersion) fail(409, 'Online analysis information has changed. Read the current information and choose again.');
      if (value.adultConfirmed !== true) fail(400, 'The child’s parent or guardian must confirm this optional permission.');
    }
    const at = new Date().toISOString();
    // Revocation always succeeds even if an older app still has old wording.
    // Events retain the grant/revocation history without modifying signed care consent.
    db.exec('BEGIN');
    try {
      db.prepare(`INSERT INTO hosted_analysis_permissions(patient_id,provider,parent_id,allowed,disclosure_version,updated_at)
        VALUES (?,?,?,?,?,?) ON CONFLICT(patient_id,provider) DO UPDATE SET
        parent_id=excluded.parent_id,allowed=excluded.allowed,disclosure_version=excluded.disclosure_version,updated_at=excluded.updated_at`)
        .run(patientId, provider, user.id, Number(value.allowed), disclosureVersion, at);
      db.prepare('INSERT INTO hosted_analysis_permission_events(patient_id,provider,parent_id,allowed,disclosure_version,updated_at) VALUES (?,?,?,?,?,?)')
        .run(patientId, provider, user.id, Number(value.allowed), disclosureVersion, at);
      db.exec('COMMIT');
    } catch (error) { db.exec('ROLLBACK'); throw error; }
    json(res, 200, snapshot(patientId));
    return true;
  };
  return { handle, allowed };
}
