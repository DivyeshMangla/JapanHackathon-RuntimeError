import { randomUUID } from 'node:crypto';
import { openDatabase, now, audit, consentVersion, nextParticipantCode, newLinkCode } from './db.mjs';
import { hashPassword } from './auth.mjs';

// Fixed codes for the demo family, so the walkthrough can be typed from the README.
const demoTherapistCode = 'MEERA7';
const demoParentCode = 'PARENT';

const exercises = [
  ['ex-name-it', 'Name it', 'Talking', 'Point to five things at home and say their names together.', ['Pick a room and look around together.', 'Your child points to something.', 'Say its name, then let your child try.']],
  ['ex-copy-me', 'Copy me', 'Talking', 'Take turns copying silly sounds and faces in a mirror.', ['Sit side by side in front of a mirror.', 'Make one sound or face.', 'Your child copies it, then it is their turn to lead.']],
  ['ex-ready-go', 'Ready, set, go', 'Playing together', 'Wait for your child to say "go" before rolling a ball.', ['Hold the ball and say "Ready, set..."', 'Pause and wait.', 'Roll it as soon as your child says or signs "go".']],
  ['ex-feelings', 'Feelings faces', 'Playing together', 'Look at picture cards and name the feeling on each face.', ['Show one card at a time.', 'Ask "How does this face feel?"', 'Make the face together.']],
].map(([id, title, program, summary, steps], index) => ({
  id, title, program, summary, steps, durationMinutes: 5, repetitions: 1, sessionsPerDay: 1,
  verificationType: 'checklist', defaultTargets: {}, evidenceSource: '', programNote: '', caution: '',
  needsInstructions: false, catalogueOrder: index + 1, approvedAt: null, approvedBy: null, archived: false,
}));

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

    for (const exercise of exercises) {
      db.prepare('INSERT INTO exercise_library VALUES (?,?,?)').run(exercise.id, JSON.stringify({ ...exercise, approvedAt: timestamp(29), approvedBy: admin }), now());
    }

    const families = [
      ['Priya Rao', 'parent@melo.test', 'Ananya'], ['Rohan Malhotra', 'rohan@melo.test', 'Kabir'], ['Simran Kaur', 'simran@melo.test', 'Zoya'],
      ['Dev Patel', 'dev@melo.test', 'Aarav'], ['Aisha Khan', 'aisha@melo.test', 'Sana'], ['Neha Verma', 'neha@melo.test', 'Ishaan'],
    ];
    families.forEach(([parentName, email, childName], i) => {
      const therapist = therapists[i % therapists.length];
      const parent = add({ name: parentName, email, role: 'parent', therapist, code: i === 0 ? demoParentCode : null, days: 28 - i });
      const child = add({ name: childName, role: 'patient', therapist, parent, days: 27 - i });
      const consent = sign(child, parent, parentName, 26 - i);
      const start = new Date(); start.setHours(0, 0, 0, 0); start.setDate(start.getDate() - 14);
      for (const exercise of exercises.slice(0, 3)) {
        const assignment = { id: randomUUID(), patientId: child, exerciseId: exercise.id, weekdays: [1, 2, 3, 4, 5, 6, 7], effectiveFrom: start.toISOString(),
          effectiveTo: null, sessionsPerDay: 1, repetitions: 1, targets: {}, instructions: '', assignedBy: therapist };
        db.prepare('INSERT INTO assignments VALUES (?,?,?,?)').run(assignment.id, child, JSON.stringify(assignment), now());
      }
      // Most days done, a few missed, so the progress charts have something to show.
      for (let day = 13; day >= 1; day--) {
        if ((day + i) % 4 === 0) continue;
        const date = new Date(); date.setDate(date.getDate() - day);
        for (const exercise of exercises.slice(0, 1 + ((day + i) % 3))) {
          db.prepare('INSERT INTO completions VALUES (?,?,?,?,?)').run(randomUUID(), child, exercise.id, date.toISOString().slice(0, 10), date.toISOString());
        }
      }
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
  Admin admin@melo.test | Therapist meera@melo.test (code ${demoTherapistCode}) | Parent parent@melo.test (code ${demoParentCode}, child Ananya)`);
  } catch (e) { db.exec('ROLLBACK'); throw e; } finally { db.close(); }
}
