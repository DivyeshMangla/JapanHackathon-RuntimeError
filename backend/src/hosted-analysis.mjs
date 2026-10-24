import { createHash } from 'node:crypto';

export const hostedAnalysisDisclosure = {
  title: 'Optional online analysis',
  provider: 'Groq',
  processingLocation: 'United States',
  text: 'I am this child’s parent or guardian and choose optional automated online analysis of their practice. The service sends the child’s practice photo or voice recording, the exercise target, and, when needed for comparison, the therapist’s reference recording to Groq in the United States. It does not send the child’s account name or profile. Automated observations and speech comparisons may be wrong and are for therapist review, not diagnosis or a validated pronunciation score. Groq may retain inputs and outputs for up to 30 days for reliability and abuse monitoring unless the service operator has enabled zero data retention. Practice and therapist feedback are still available without this permission. I can turn off future online requests here; turning this off cannot recall data already processed. This is a separate, optional permission and does not change the care consent already signed.',
  privacyUrl: 'https://console.groq.com/docs/your-data',
};

// A disclosure change invalidates an earlier grant until the parent sees and
// explicitly accepts the new wording. No child's media or names are stored here.
export const hostedAnalysisDisclosureVersion = `groq-${createHash('sha256')
  .update(JSON.stringify(hostedAnalysisDisclosure)).digest('hex').slice(0, 20)}`;

export function hostedAnalysis({ db, body, fail, json, accessPatient, requireRole }) {
  db.exec(`
    CREATE TABLE IF NOT EXISTS hosted_analysis_permissions (
      patient_id TEXT NOT NULL REFERENCES users(id),
      provider TEXT NOT NULL CHECK(provider='groq'),
      parent_id TEXT NOT NULL REFERENCES users(id),
      allowed INTEGER NOT NULL CHECK(allowed IN (0,1)),
      disclosure_version TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      PRIMARY KEY(patient_id,provider)
    );
    CREATE TABLE IF NOT EXISTS hosted_analysis_permission_events (
      seq INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id TEXT NOT NULL REFERENCES users(id),
      provider TEXT NOT NULL CHECK(provider='groq'),
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
  const record = patientId => db.prepare("SELECT * FROM hosted_analysis_permissions WHERE patient_id=? AND provider='groq'").get(patientId);
  const allowed = (patientId, provider = 'groq') => {
    if (provider !== 'groq' || !care(patientId).approved) return false;
    const permission = record(patientId);
    if (!permission || permission.allowed !== 1 || permission.disclosure_version !== hostedAnalysisDisclosureVersion) return false;
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
      provider: 'groq',
      allowed: granted,
      careConsentApproved: original.approved,
      localAnalysisAllowed: original.localAnalysisAllowed,
      analysisAllowed: original.localAnalysisAllowed || granted,
      disclosureVersion: hostedAnalysisDisclosureVersion,
      disclosure: hostedAnalysisDisclosure,
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
      if (value.disclosureVersion !== hostedAnalysisDisclosureVersion) fail(409, 'Online analysis information has changed. Read the current information and choose again.');
      if (value.adultConfirmed !== true) fail(400, 'The child’s parent or guardian must confirm this optional permission.');
    }
    const at = new Date().toISOString();
    // Revocation always succeeds even if an older app still has old wording.
    // Events retain the grant/revocation history without modifying signed care consent.
    db.exec('BEGIN');
    try {
      db.prepare(`INSERT INTO hosted_analysis_permissions(patient_id,provider,parent_id,allowed,disclosure_version,updated_at)
        VALUES (?,'groq',?,?,?,?) ON CONFLICT(patient_id,provider) DO UPDATE SET
        parent_id=excluded.parent_id,allowed=excluded.allowed,disclosure_version=excluded.disclosure_version,updated_at=excluded.updated_at`)
        .run(patientId, user.id, Number(value.allowed), hostedAnalysisDisclosureVersion, at);
      db.prepare("INSERT INTO hosted_analysis_permission_events(patient_id,provider,parent_id,allowed,disclosure_version,updated_at) VALUES (?,'groq',?,?,?,?)")
        .run(patientId, user.id, Number(value.allowed), hostedAnalysisDisclosureVersion, at);
      db.exec('COMMIT');
    } catch (error) { db.exec('ROLLBACK'); throw error; }
    json(res, 200, snapshot(patientId));
    return true;
  };
  return { handle, allowed };
}
