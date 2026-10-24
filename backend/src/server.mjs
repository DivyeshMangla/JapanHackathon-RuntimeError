import { createServer } from 'node:http';
import { usefulWords } from './useful-words.mjs';
import { randomUUID } from 'node:crypto';
import { readFile, writeFile, unlink } from 'node:fs/promises';
import { resolve, extname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { openDatabase, root, now, publicUser, audit, exercises, consentVersion, consentText } from './db.mjs';
import { hashPassword, verifyPassword, newSession, authenticate, requestToken, tokenHash } from './auth.mjs';

class HttpError extends Error { constructor(status, message) { super(message); this.status = status; } }
const fail = (status, message) => { throw new HttpError(status, message); };
const text = (value, name, max = 200) => {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail(400, `${name} is required (maximum ${max} characters).`);
  return value.trim();
};
const integer = (v, name, min, max) => {
  if (!Number.isInteger(v) || v < min || v > max) fail(400, `${name} must be between ${min} and ${max}.`);
  return v;
};
async function body(req, max = 1024 * 1024) {
  if (!req.headers['content-type']?.startsWith('application/json')) fail(415, 'Send application/json.');
  let size = 0; const parts = [];
  for await (const chunk of req) { size += chunk.length; if (size > max) fail(413, 'Upload is too large.'); parts.push(chunk); }
  try { const result = JSON.parse(Buffer.concat(parts).toString()); if (!result || Array.isArray(result) || typeof result !== 'object') throw Error(); return result; }
  catch { fail(400, 'Invalid JSON body.'); }
}
function json(res, status, value) { res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(value)); }

export function createApp({ dataDir = process.env.DATA_DIR || resolve(root, 'data'), secureCookies = process.env.NODE_ENV === 'production', origin = process.env.PUBLIC_ORIGIN, transcriber } = {}) {
  const db = openDatabase(dataDir);
  const findUser = id => db.prepare('SELECT * FROM users WHERE id=?').get(id);
  const requireRole = (u, ...roles) => { if (!roles.includes(u.role)) fail(403, 'You do not have access to this action.'); };
  const accessPatient = (u, id) => {
    const p = findUser(id);
    if (!p || p.role !== 'patient') fail(404, 'Patient not found.');
    if (u.role !== 'admin' && u.id !== p.id && !(u.role === 'therapist' && p.therapist_id === u.id)) fail(403, 'This patient is not assigned to you.');
    return p;
  };
  const planFor = p => db.prepare('SELECT * FROM plans WHERE patient_id=? ORDER BY created_at DESC, rowid DESC LIMIT 1').get(p);
  const consentFor = p => db.prepare('SELECT * FROM consents WHERE patient_id=? ORDER BY signed_at DESC, rowid DESC LIMIT 1').get(p);
  const unpackPlan = p => p ? { ...p, exercises: JSON.parse(p.exercises) } : null;
  const unpackConsent = c => c ? { ...c, checks: JSON.parse(c.checks) } : null;
  const patientSummary = p => {
    const consent = consentFor(p.id), plan = planFor(p.id);
    const activity = db.prepare(`SELECT COUNT(*) AS sessions, COALESCE(SUM(minutes),0) AS minutes,
      MAX(completed_at) AS last_practice FROM progress WHERE patient_id=?`).get(p.id);
    const firstDay = new Date(); firstDay.setUTCHours(0,0,0,0); firstDay.setUTCDate(firstDay.getUTCDate()-6);
    const days = db.prepare("SELECT COUNT(DISTINCT substr(completed_at,1,10)) AS n FROM progress WHERE patient_id=? AND completed_at>=?").get(p.id, firstDay.toISOString()).n;
    return { ...publicUser(p), therapist_name: findUser(p.therapist_id)?.name || null, consent_status: consent?.status || 'missing', has_plan: !!plan, active_days: days, ...activity };
  };
  const wordRoutes = usefulWords({ db, dataDir, fail, text, body, json, findUser, transcriber });
  const server = createServer(async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'same-origin');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; media-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
    try {
      const url = new URL(req.url, 'http://localhost'); const path = url.pathname; const method = req.method;
      const allowedOrigin = origin || `http://${req.headers.host}`;
      if (req.headers.origin && req.headers.origin !== allowedOrigin) fail(403, 'Cross-origin requests are not allowed.');
      if (path === '/api/health') return json(res, 200, { status: 'ok' });
      if (path === '/api/config') return json(res, 200, { demo: db.prepare("SELECT value FROM settings WHERE key='demo'").get()?.value === 'true', consentVersion, consentText, exercises });
      if (path === '/api/auth/login' && method === 'POST') {
        const b = await body(req); const email = text(b.email, 'Email').toLowerCase(); const password = text(b.password, 'Password', 128);
        const key = `${req.socket.remoteAddress}:${email}`;
        const ipKey = `ip:${req.socket.remoteAddress}`;
        for (const k of [key, ipKey]) {
          const a = db.prepare('SELECT * FROM login_attempts WHERE key=?').get(k);
          if (a && a.reset_at > Date.now() && a.failures >= (k === key ? 5 : 30)) fail(429, 'Too many attempts. Try again in 15 minutes.');
        }
        const u = db.prepare('SELECT * FROM users WHERE email=?').get(email);
        // A valid dummy hash keeps unknown-account requests on the same slow path.
        const dummy = 'scrypt:00000000000000000000000000000000:' + '00'.repeat(64);
        const valid = await verifyPassword(password, u?.password_hash || dummy);
        if (!valid || !u) {
          for (const k of [key, ipKey]) db.prepare(`INSERT INTO login_attempts VALUES (?,1,?) ON CONFLICT(key) DO UPDATE SET
            failures=CASE WHEN reset_at<? THEN 1 ELSE failures+1 END, reset_at=CASE WHEN reset_at<? THEN excluded.reset_at ELSE reset_at END`).run(k, Date.now() + 900000, Date.now(), Date.now());
          fail(401, 'Email or password is incorrect.');
        }
        if (u.status !== 'active') fail(403, u.status === 'pending' ? 'Your therapist registration is awaiting administrator approval.' : 'This account is disabled. Contact your administrator.');
        db.prepare('DELETE FROM login_attempts WHERE key=?').run(key);
        const token = newSession(db, u.id);
        res.setHeader('Set-Cookie', `vp_session=${token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=604800${secureCookies ? '; Secure' : ''}`);
        audit(db, u.id, 'Signed in', u.id);
        return json(res, 200, { user: publicUser(u), ...(b.client === 'mobile' ? { token } : {}) });
      }
      if (path === '/api/auth/register' && method === 'POST') {
        const b = await body(req);
        if (!['patient', 'therapist'].includes(b.role)) fail(400, 'Choose patient or therapist.');
        // Rate-limit public registration independently of credential attempts.
        const key = `register:${req.socket.remoteAddress}`;
        const attempts = db.prepare('SELECT * FROM login_attempts WHERE key=?').get(key);
        if (attempts?.reset_at > Date.now() && attempts.failures >= 10) fail(429, 'Too many registrations. Try again later.');
        const user = await createUser(b, null);
        db.prepare(`INSERT INTO login_attempts VALUES (?,1,?) ON CONFLICT(key) DO UPDATE SET failures=CASE WHEN reset_at<? THEN 1 ELSE failures+1 END, reset_at=excluded.reset_at`).run(key, Date.now() + 3600000, Date.now());
        return json(res, 201, { user });
      }
      if (path.startsWith('/api/')) {
        const u = authenticate(db, req); if (!u) fail(401, 'Please sign in.');
        if (await wordRoutes(req, res, url, u)) return;
        if (path === '/api/auth/me' && method === 'GET') return json(res, 200, { user: publicUser(u) });
        if (path === '/api/auth/logout' && method === 'POST') {
          db.prepare('DELETE FROM sessions WHERE token_hash=?').run(tokenHash(requestToken(req)));
          res.setHeader('Set-Cookie', `vp_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0${secureCookies ? '; Secure' : ''}`);
          return json(res, 200, { ok: true });
        }
        if (path === '/api/auth/password' && method === 'POST') {
          const b = await body(req); const old = text(b.currentPassword, 'Current password', 128);
          if (!await verifyPassword(old, u.password_hash)) fail(400, 'Current password is incorrect.');
          const password = validatePassword(b.password); const hash = await hashPassword(password);
          db.prepare('UPDATE users SET password_hash=? WHERE id=?').run(hash, u.id);
          db.prepare('DELETE FROM sessions WHERE user_id=?').run(u.id);
          audit(db, u.id, 'Changed password', u.id); return json(res, 200, { ok: true });
        }
        if (path === '/api/overview' && method === 'GET') {
          requireRole(u, 'admin');
          const patients = db.prepare("SELECT * FROM users WHERE role='patient'").all().map(patientSummary);
          const therapists = db.prepare("SELECT id,name,email,clinic,registration,status,created_at FROM users WHERE role='therapist' ORDER BY created_at DESC").all();
          const days = Array.from({ length: 14 }, (_, i) => new Date(Date.now() - (13-i)*86400000).toISOString().slice(0,10));
          const activity = days.map(day => ({ day, sessions: db.prepare('SELECT COUNT(*) AS n FROM progress WHERE substr(completed_at,1,10)=?').get(day).n }));
          return json(res, 200, { patients, therapists, activity, recordings: db.prepare('SELECT COUNT(*) AS n FROM recordings').get().n,
            audit: db.prepare('SELECT a.*,u.name AS actor_name FROM audit a LEFT JOIN users u ON u.id=a.actor_id ORDER BY a.created_at DESC,a.rowid DESC LIMIT 8').all() });
        }
        if (path === '/api/users' && method === 'GET') {
          requireRole(u, 'admin'); return json(res, 200, { users: db.prepare('SELECT * FROM users ORDER BY created_at DESC').all().map(publicUser) });
        }
        if (path === '/api/users' && method === 'POST') {
          requireRole(u, 'admin'); return json(res, 201, { user: await createUser(await body(req), u.id) });
        }
        const userMatch = path.match(/^\/api\/users\/([^/]+)$/);
        if (userMatch && method === 'PATCH') {
          requireRole(u, 'admin'); const target = findUser(userMatch[1]); if (!target) fail(404, 'Account not found.');
          const b = await body(req);
          if (target.role === 'admin') fail(400, 'Administrator accounts cannot be modified here.');
          if (!['active', 'disabled'].includes(b.status)) fail(400, 'Choose active or disabled.');
          db.prepare('UPDATE users SET status=? WHERE id=?').run(b.status, target.id);
          if (b.status === 'disabled') db.prepare('DELETE FROM sessions WHERE user_id=?').run(target.id);
          audit(db, u.id, target.status === 'pending' && b.status === 'active' ? 'Approved therapist' : `Account ${b.status}`, target.id, target.name);
          return json(res, 200, { user: publicUser(findUser(target.id)) });
        }
        if (path === '/api/patients' && method === 'GET') {
          requireRole(u, 'admin', 'therapist'); const rows = u.role === 'admin' ? db.prepare("SELECT * FROM users WHERE role='patient'").all() : db.prepare("SELECT * FROM users WHERE role='patient' AND therapist_id=?").all(u.id);
          return json(res, 200, { patients: rows.map(patientSummary) });
        }
        const patientMatch = path.match(/^\/api\/patients\/([^/]+)(?:\/(assignment|consent|approve-consent|forms|plans|progress|recordings))?$/);
        if (patientMatch) {
          const id = patientMatch[1]; const action = patientMatch[2]; const p = accessPatient(u, id);
          if (!action && method === 'GET') return json(res, 200, { patient: patientSummary(p), consent: unpackConsent(consentFor(id)), plan: unpackPlan(planFor(id)),
            forms: u.role === 'patient' ? null : db.prepare('SELECT * FROM clinical_forms WHERE patient_id=?').get(id) || null,
            progress: db.prepare('SELECT * FROM progress WHERE patient_id=? ORDER BY completed_at DESC LIMIT 100').all(id),
            recordings: db.prepare('SELECT id,exercise_id,mime,bytes,duration_seconds,created_at,review_note FROM recordings WHERE patient_id=? ORDER BY created_at DESC LIMIT 100').all(id) });
          if (action === 'assignment' && method === 'PUT') {
            requireRole(u, 'admin'); const b = await body(req); const therapist = b.therapistId ? findUser(b.therapistId) : null;
            if (b.therapistId && (!therapist || therapist.role !== 'therapist' || therapist.status !== 'active')) fail(400, 'Choose an approved, active therapist.');
            db.prepare('UPDATE users SET therapist_id=? WHERE id=?').run(therapist?.id || null, id);
            audit(db, u.id, 'Updated assignment', id, `${p.name} → ${therapist?.name || 'Unassigned'}`);
            return json(res, 200, { patient: patientSummary(findUser(id)) });
          }
          if (action === 'consent' && method === 'POST') {
            requireRole(u, 'patient'); const b = await body(req);
            if (consentFor(id)) fail(409, 'Consent has already been submitted.');
            if (b.version !== consentVersion || b.checks?.adult !== true || b.checks?.participation !== true || b.checks?.dataSharing !== true || typeof b.checks?.analysis !== 'boolean') fail(400, 'Complete all required consent items.');
            const signer = text(b.signerName, 'Signer name'); const png = text(b.signaturePng, 'Signature', 700000);
            if (!Buffer.from(png, 'base64').subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) fail(400, 'A PNG signature is required.');
            db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES (?,?,?,?,?,?,?,?)').run(randomUUID(), id, consentVersion, signer, png, JSON.stringify(b.checks), 'pending', now());
            audit(db, u.id, 'Submitted consent', id); return json(res, 201, { consent: unpackConsent(consentFor(id)) });
          }
          if (action === 'approve-consent' && method === 'POST') {
            requireRole(u, 'therapist'); const b = await body(req); const consent = consentFor(id);
            if (!consent || consent.status !== 'pending') fail(409, 'No consent awaiting approval.');
            if (b.paperCopy !== true) fail(400, 'Confirm the paper copy before approval.');
            db.prepare("UPDATE consents SET status='approved',approved_by=?,approved_at=?,paper_copy=1 WHERE id=?").run(u.id, now(), consent.id);
            audit(db, u.id, 'Approved consent', id, p.name); return json(res, 200, { consent: unpackConsent(consentFor(id)) });
          }
          if (action === 'forms' && method === 'PUT') {
            requireRole(u, 'therapist'); const b = await body(req);
            if (consentFor(id)?.status !== 'approved') fail(409, 'Approve consent before saving clinical forms.');
            db.prepare(`INSERT INTO clinical_forms VALUES (?,?,?,?,?,?) ON CONFLICT(patient_id) DO UPDATE SET age=excluded.age,demographic=excluded.demographic,clinical=excluded.clinical,saved_by=excluded.saved_by,updated_at=excluded.updated_at`).run(id,integer(b.age,'Age',18,120),text(b.demographic,'Demographic information',2000),text(b.clinical,'Clinical information',2000),u.id,now());
            audit(db,u.id,'Saved clinical forms',id,p.name); return json(res,200,{ok:true});
          }
          if (action === 'plans' && method === 'POST') {
            requireRole(u, 'therapist'); const b = await body(req); const consent = consentFor(id);
            if (!consent || consent.status !== 'approved') fail(409, 'Approve consent before prescribing a plan.');
            if (!db.prepare('SELECT patient_id FROM clinical_forms WHERE patient_id=?').get(id)) fail(409, 'Save clinical forms before prescribing a plan.');
            if (p.status !== 'active') fail(409, 'Patient account is disabled.');
            if (!Array.isArray(b.exercises) || b.exercises.length < 1 || b.exercises.length > 6 || new Set(b.exercises).size !== b.exercises.length || !b.exercises.every(e => exercises.some(x => x.id === e))) fail(400, 'Choose one to six different exercises from the library.');
            const planId = randomUUID();
            db.prepare('INSERT INTO plans VALUES (?,?,?,?,?,?,?,?,?)').run(planId,id,u.id,consent.id,text(b.title,'Plan title'),JSON.stringify(b.exercises),integer(b.sessionsPerDay,'Sessions per day',1,5),typeof b.notes === 'string' ? b.notes.slice(0,2000) : '',now());
            audit(db,u.id,'Prescribed plan',id,p.name); return json(res,201,{plan:unpackPlan(planFor(id))});
          }
          if (action === 'progress' && method === 'POST') {
            requireRole(u,'patient'); const b=await body(req); const plan=db.prepare('SELECT * FROM plans WHERE id=? AND patient_id=?').get(b.planId || '',id);
            if (!plan || !JSON.parse(plan.exercises).includes(b.exerciseId)) fail(400,'Exercise does not belong to your plan.');
            const eventId=text(b.id,'Event ID',80); const minutes=integer(b.minutes,'Practice minutes',1,120);
            const date=new Date(b.completedAt); if (!Number.isFinite(date.getTime()) || date.getTime()>Date.now()+300000 || date.getTime()<new Date(plan.created_at).getTime()) fail(400,'Invalid practice time.');
            const existing=db.prepare('SELECT * FROM progress WHERE id=?').get(eventId);
            if(existing && (existing.patient_id!==id || existing.plan_id!==b.planId || existing.exercise_id!==b.exerciseId || existing.minutes!==minutes || existing.completed_at!==date.toISOString())) fail(409,'Event ID conflicts with an existing entry.');
            if(!existing) db.prepare('INSERT INTO progress VALUES (?,?,?,?,?,?,?)').run(eventId,id,plan.id,b.exerciseId,minutes,date.toISOString(),now());
            return json(res,200,{ok:true,id:eventId});
          }
          if (action === 'recordings' && method === 'POST') {
            requireRole(u,'patient'); const b=await body(req,16*1024*1024); const plan=db.prepare('SELECT * FROM plans WHERE id=? AND patient_id=?').get(b.planId || '',id);
            if(!plan || !JSON.parse(plan.exercises).includes(b.exerciseId)) fail(400,'Exercise does not belong to your plan.');
            const recordingId=text(b.id,'Recording ID',80); if(!/^[a-zA-Z0-9-]+$/.test(recordingId)) fail(400,'Invalid recording ID.');
            const existing=db.prepare('SELECT * FROM recordings WHERE id=?').get(recordingId);
            if(existing) { if(existing.patient_id!==id) fail(409,'Recording ID conflict.'); return json(res,200,{id:recordingId}); }
            const duration=integer(b.durationSeconds,'Recording seconds',1,120);
            if(typeof b.audio!=='string' || !/^[A-Za-z0-9+/]*={0,2}$/.test(b.audio)) fail(400,'Invalid audio encoding.');
            const audio=Buffer.from(b.audio,'base64');
            if(audio.length<44 || audio.length>12*1024*1024 || audio.toString('ascii',0,4)!=='RIFF' || audio.toString('ascii',8,12)!=='WAVE') fail(400,'Upload a WAV recording, up to 12 MB.');
            const filename=`${recordingId}.wav`; await writeFile(resolve(dataDir,'uploads',filename),audio,{flag:'wx'}).catch(()=>fail(409,'Recording upload conflict.'));
            try { db.prepare('INSERT INTO recordings(id,patient_id,plan_id,exercise_id,filename,mime,bytes,duration_seconds,created_at) VALUES (?,?,?,?,?,?,?,?,?)').run(recordingId,id,plan.id,b.exerciseId,filename,'audio/wav',audio.length,duration,now()); }
            catch(e) { await unlink(resolve(dataDir,'uploads',filename)); throw e; }
            audit(db,u.id,'Uploaded recording',id,p.name); return json(res,201,{id:recordingId});
          }
        }
        const recordingMatch=path.match(/^\/api\/recordings\/([^/]+)(?:\/(audio|review))?$/);
        if(recordingMatch) {
          const r=db.prepare('SELECT * FROM recordings WHERE id=?').get(recordingMatch[1]); if(!r) fail(404,'Recording not found.'); accessPatient(u,r.patient_id);
          if(recordingMatch[2]==='audio' && method==='GET') {
            const audio=await readFile(resolve(dataDir,'uploads',r.filename));
            // Every listen to a patient's voice is part of the access record.
            audit(db,u.id,'Played recording',r.patient_id,r.id);
            res.writeHead(200,{'Content-Type':r.mime,'Content-Length':audio.length}); return res.end(audio);
          }
          if(recordingMatch[2]==='review' && method==='POST') { requireRole(u,'therapist'); const b=await body(req); db.prepare('UPDATE recordings SET review_note=?,reviewed_by=? WHERE id=?').run(text(b.note,'Review note',2000),u.id,r.id); audit(db,u.id,'Reviewed recording',r.patient_id); return json(res,200,{ok:true}); }
        }
        if(path==='/api/audit' && method==='GET') { requireRole(u,'admin'); return json(res,200,{events:db.prepare('SELECT a.*,u.name AS actor_name FROM audit a LEFT JOIN users u ON u.id=a.actor_id ORDER BY a.created_at DESC,a.rowid DESC LIMIT 200').all()}); }
        fail(404,'API endpoint not found.');
      }
      if(method!=='GET') fail(405,'Method not allowed.');
      const staticFiles={'/':'index.html','/index.html':'index.html','/app.js':'app.js','/styles.css':'styles.css','/favicon.svg':'favicon.svg'};
      const fonts={'/fonts/Inter-Regular.ttf':'Inter-Regular.ttf','/fonts/Inter-Medium.ttf':'Inter-Medium.ttf','/fonts/Inter-SemiBold.ttf':'Inter-SemiBold.ttf'};
      const file=staticFiles[path] ? resolve(root,'../admin',staticFiles[path]) : fonts[path] ? resolve(root,'../assets/fonts',fonts[path]) : null;
      if(!file) fail(404,'Page not found.');
      const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.ttf':'font/ttf'};
      res.writeHead(200,{'Content-Type':mime[extname(file)]}); res.end(await readFile(file));
    } catch(error) { if(!res.headersSent) json(res,error.status || 500,{error:error.status ? error.message : 'Something went wrong. Please retry.'}); else res.end(); if(!error.status) console.error(error); }
  });
  function validatePassword(value) { if(typeof value!=='string' || value.length<10 || value.length>128 || value!==value.trim()) fail(400,'Use a password of 10–128 characters without leading or trailing spaces.'); return value; }
  async function createUser(b, actor) {
    if(!['patient','therapist'].includes(b.role)) fail(400,'Choose patient or therapist.');
    const name=text(b.name,'Name'); const email=text(b.email,'Email').toLowerCase(); if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) fail(400,'Enter a valid email.');
    const password=validatePassword(b.password); const clinic=b.role==='therapist'?text(b.clinic,'Clinic'):''; const registration=b.role==='therapist'?text(b.registration,'Registration number'):'';
    const hash=await hashPassword(password); const id=randomUUID();
    // A therapist who registers themselves waits for approval; one an
    // administrator creates is approved by that act.
    const status=b.role==='therapist' && !actor ? 'pending' : 'active';
    try { db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,clinic,registration,created_at) VALUES (?,?,?,?,?,?,?,?,?)').run(id,name,email,hash,b.role,status,clinic,registration,now()); }
    catch(error) { if(error.code?.includes('SQLITE') && String(error).includes('UNIQUE')) fail(409,'An account with this email already exists.'); throw error; }
    audit(db,actor,'Created account',id,`${name} · ${b.role}`); return publicUser(findUser(id));
  }
  return {server,db};
}
if(process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  const {server}=createApp(); const port=Number(process.env.PORT || 8787); const host=process.env.HOST || '127.0.0.1';
  server.listen(port,host,()=>console.log(`Melo admin: http://${host}:${port}`));
}
