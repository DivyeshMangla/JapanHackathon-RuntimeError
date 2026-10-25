import { createHash, randomUUID } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { openDatabase, root, now, audit, consentVersion, nextParticipantCode, newLinkCode } from './db.mjs';
import { hashPassword } from './auth.mjs';
import { expressionPictures, expressionsApi } from './expressions.mjs';
import { motorExercises } from './motor.mjs';
import { motorApi } from './motor-api.mjs';
import { motorReference } from './motor-reference.mjs';

// A fixed therapist code, so the parent sign-up walkthrough can be typed from the README.
const demoTherapistCode = 'MEERA7';

const dataDir = process.env.DATA_DIR || resolve(root, 'data');
const db = openDatabase(dataDir);

// Six weeks of practice for the first child, so the progress trend has a story to show.
function seedHistory({ child, therapist, plan, timestamp }) {
  const feelings = ['happy', 'sad', 'angry', 'surprised'];
  const expressions = expressionsApi({ db, dataDir });
  const assignment = expressions.assign(child, therapist, feelings, true, timestamp(39));
  const rounds = [
    [37, 3, 'with_help', 'Ananya matched happy right away. Angry and surprised still look alike to her; point out the eyebrows together.'],
    [35, 4, 'with_help'], [30, 4, 'with_help'],
    [28, 5, 'with_help', 'Good progress on sad. Try naming the feeling in a picture book at bedtime.'],
    [23, 5, 'independent'], [21, 6, 'independent'],
    [16, 6, 'independent', 'She is now choosing on her own most of the time. Keep rounds short and fun.'],
    [14, 7, 'independent'], [9, 7, 'independent'], [7, 7, 'independent'],
    [3, 8, 'independent', 'All eight pictures matched without help. Lovely work, Ananya.'], [1, 8, 'independent'],
  ];
  for (const [days, correct, assistance, note] of rounds) {
    const id = randomUUID();
    const answers = expressionPictures(feelings).map((pictureId, index) => {
      const expected = pictureId.slice(0, pictureId.lastIndexOf('-'));
      // Early mistakes fall on the later feelings, which are the harder ones.
      const selected = index < correct ? expected : feelings[(feelings.indexOf(expected) + 1) % feelings.length];
      return { pictureId, selected };
    });
    expressions.record(id, child, assignment, answers, assistance, timestamp(days));
    if (note) expressions.review({ id, patient_id: child }, note, therapist, timestamp(days - 0.5));
  }

  motorApi({ db, dataDir });
  const drawings = [
    [36, 'motor-lines', 'needs_practice', 'Lines wander upward at the end. Hold the paper with the other hand and slow down.'],
    [33, 'motor-shapes', 'needs_practice', 'The circles do not quite close yet. Trace one in the air first.'],
    [29, 'motor-lines', 'needs_practice', 'A little straighter than last time. Keep the pace slow.'],
    [26, 'motor-letter', 'needs_practice', 'The L stems are leaning. Start at the top and pull straight down.'],
    [22, 'motor-shapes', 'on_track', 'Both circles closed this time. Well done.'],
    [19, 'motor-lines', 'on_track', 'Much steadier lines this week.'],
    [15, 'motor-letter', 'needs_practice', 'Two of the three Ls are upright. Rest your hand between letters.'],
    [12, 'motor-shapes', 'on_track', 'Circles are closing neatly now.'],
    [8, 'motor-letter', 'on_track', 'Three clear Ls sitting on the same line.'],
    [5, 'motor-lines', 'on_track', 'Smooth, even lines from start to finish.'],
    [2, 'motor-letter', null],
  ];
  for (const [days, exerciseId, outcome, note] of drawings) {
    const id = randomUUID();
    const exercise = motorExercises.find(candidate => candidate.id === exerciseId);
    const photo = motorReference(exercise);
    const filename = `motor-${id}.png`;
    writeFileSync(resolve(dataDir, 'uploads', filename), photo, { flag: 'wx' });
    const createdAt = timestamp(days);
    db.prepare('INSERT INTO motor_submissions(id,patient_id,plan_id,exercise_id,filename,mime,bytes,photo_hash,practice_day,created_at,analysis_status,review_note,reviewed_by,reviewed_at,therapist_outcome) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)')
      .run(id, child, plan, exerciseId, filename, 'image/png', photo.length, createHash('sha256').update(photo).digest('hex'),
        createdAt.slice(0, 10), createdAt, 'unavailable', outcome ? note : null, outcome ? therapist : null,
        outcome ? timestamp(days - 0.5) : null, outcome || 'not_assessed');
    db.prepare('INSERT INTO progress VALUES(?,?,?,?,?,?,?)').run(`motor-${id}`, child, plan, exerciseId, exercise.minutes, createdAt, createdAt);
  }
}
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
      const parent = add({ name: parentName, email, role: 'parent', therapist, days: 42 - i });
      const child = add({ name: childName, role: 'patient', therapist, parent, days: 41 - i });
      const consent = sign(child, parent, parentName, 40 - i);
      if (i === 0) {
        const plan = randomUUID();
        db.prepare('INSERT INTO plans VALUES (?,?,?,?,?,?,?,?,?)').run(plan, child, therapist, consent, 'My drawing practice',
          JSON.stringify(['motor-lines', 'motor-shapes', 'motor-letter']), 1, 'Take your time and rest when your hand feels tired.', timestamp(39));
        audit(db, therapist, 'Prescribed plan', child, childName);
        seedHistory({ child, therapist, plan, timestamp });
      }
    });
    audit(db, admin, 'Demo workspace created', null, 'Synthetic records for local development');
    db.prepare('INSERT INTO settings VALUES (?,?)').run('demo', 'true');
    db.exec('COMMIT');
    console.log(`Demo workspace created. Password for every account: VoiceDemo!2026
  Admin admin@melo.test | Therapist meera@melo.test (code ${demoTherapistCode}) | Parent parent@melo.test (child Ananya)`);
  } catch (e) { db.exec('ROLLBACK'); throw e; } finally { db.close(); }
}
