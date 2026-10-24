import { randomUUID } from 'node:crypto';
import { openDatabase, now, audit, consentVersion, nextParticipantCode, newLinkCode } from './db.mjs';
import { hashPassword } from './auth.mjs';

// A fixed therapist code, so the parent sign-up walkthrough can be typed from the README.
const demoTherapistCode = 'MEERA7';

const db = openDatabase();
if (db.prepare('SELECT COUNT(*) AS n FROM users').get().n) {
  console.log('Database already contains accounts; demo seed skipped.'); db.close();
} else {
  const hash = await hashPassword('VoiceDemo!2026');
  const timestamp = days => new Date(Date.now() - days * 86400000).toISOString();
  const add = ({ name, email, role, status = 'active', therapist = null, parent = null, code = null, days = 30 }) => {
    const id = randomUUID();
    db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,clinic,registration,therapist_id,parent_id,created_at,participant_code,link_code) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)')
      .run(id, name, email || `child-${id}@family.melo.invalid`, hash, role, status,
        role === 'therapist' ? 'Melo Therapy Clinic' : '', role === 'therapist' ? `REG-${Math.floor(10000 + Math.random() * 90000)}` : '',
        therapist, parent, timestamp(days), role === 'patient' ? nextParticipantCode(db) : null,
        ['therapist', 'parent'].includes(role) ? code || newLinkCode(db) : null);
    return id;
  };
  const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=';
  const sign = (child, parent, parentName, days) => {
    const id = randomUUID();
    db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at,approved_by,approved_at,paper_copy) VALUES (?,?,?,?,?,?,?,?,?,?,?)')
      .run(id, child, consentVersion, parentName, png, JSON.stringify({ adult: true, participation: true, dataSharing: true, analysis: true }), 'approved', timestamp(days), parent, timestamp(days), 0);
    return id;
  };
  db.exec('BEGIN');
  try {
    const admin = add({ name: 'Alex Morgan', email: 'admin@melo.test', role: 'admin' });
    const meera = add({ name: 'Dr. Meera Kapoor', email: 'meera@melo.test', role: 'therapist', code: demoTherapistCode });
    const therapists = [meera, add({ name: 'Dr. Arjun Singh', email: 'arjun@melo.test', role: 'therapist' })];
    add({ name: 'Dr. Riya Sharma', email: 'riya@melo.test', role: 'therapist', status: 'pending', days: 1 });

    const families = [
      ['Priya Rao', 'parent@melo.test', 'Ananya'], ['Rohan Malhotra', 'rohan@melo.test', 'Kabir'], ['Simran Kaur', 'simran@melo.test', 'Zoya'],
      ['Dev Patel', 'dev@melo.test', 'Aarav'], ['Aisha Khan', 'aisha@melo.test', 'Sana'], ['Neha Verma', 'neha@melo.test', 'Ishaan'],
    ];
    families.forEach(([parentName, email, childName], i) => {
      const therapist = therapists[i % therapists.length];
      const parent = add({ name: parentName, email, role: 'parent', therapist, days: 28 - i });
      const child = add({ name: childName, role: 'patient', therapist, parent, days: 27 - i });
      const consent = sign(child, parent, parentName, 26 - i);
      if (i === 0) {
        db.prepare('INSERT INTO plans VALUES (?,?,?,?,?,?,?,?,?)').run(randomUUID(), child, therapist, consent, 'My drawing practice',
          JSON.stringify(['motor-lines', 'motor-shapes', 'motor-letter']), 1, 'Take your time and rest when your hand feels tired.', timestamp(20));
        audit(db, therapist, 'Prescribed plan', child, childName);
      }
    });
    audit(db, admin, 'Demo workspace created', null, 'Synthetic records for local development');
    db.prepare('INSERT INTO settings VALUES (?,?)').run('demo', 'true');
    db.exec('COMMIT');
    console.log(`Demo workspace created. Password for every account: VoiceDemo!2026
  Admin admin@melo.test | Therapist meera@melo.test (code ${demoTherapistCode}) | Parent parent@melo.test (child Ananya)`);
  } catch (e) { db.exec('ROLLBACK'); throw e; } finally { db.close(); }
}
