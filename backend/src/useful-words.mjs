import { createCipheriv, createDecipheriv, randomBytes, randomUUID, createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { consentVersion } from './db.mjs';

// Recognition is deliberately independent of accepting audio. Replace this seam
// with a server-side recognizer; it must never change the stored original.
export class UnavailableTranscriber {
  async suggest() { throw new Error('Mock integration: no speech recognition service configured'); }
}

export function usefulWords({ db, dataDir, fail, text, body, json, findUser, transcriber = new UnavailableTranscriber() }) {
  let key;
  if (process.env.USEFUL_WORDS_KEY) {
    key = Buffer.from(process.env.USEFUL_WORDS_KEY, 'base64');
    if (key.length !== 32) throw Error('USEFUL_WORDS_KEY must be a base64-encoded 32-byte key');
  } else {
    if (process.env.NODE_ENV === 'production') throw Error('USEFUL_WORDS_KEY is required in production');
    const keyPath = resolve(dataDir, 'useful-words.key');
    try { key = readFileSync(keyPath); }
    catch (error) {
      if (error.code !== 'ENOENT') throw error;
      key = randomBytes(32); writeFileSync(keyPath, key, { mode: 0o600, flag: 'wx' });
    }
  }
  db.exec(`CREATE TABLE IF NOT EXISTS useful_word_records (
    kind TEXT NOT NULL, id TEXT NOT NULL, patient_id TEXT NOT NULL REFERENCES users(id),
    payload BLOB NOT NULL, PRIMARY KEY(kind,id));
    CREATE INDEX IF NOT EXISTS useful_word_patient ON useful_word_records(patient_id,kind);`);
  const seal = value => {
    const nonce = randomBytes(12), cipher = createCipheriv('aes-256-gcm', key, nonce);
    const encrypted = Buffer.concat([cipher.update(JSON.stringify(value)), cipher.final()]);
    return Buffer.concat([nonce, cipher.getAuthTag(), encrypted]);
  };
  const open = row => {
    if (!row) return null;
    const bytes = Buffer.from(row.payload), cipher = createDecipheriv('aes-256-gcm', key, bytes.subarray(0,12));
    cipher.setAuthTag(bytes.subarray(12,28));
    return JSON.parse(Buffer.concat([cipher.update(bytes.subarray(28)), cipher.final()]).toString());
  };
  const get = (kind,id) => open(db.prepare('SELECT payload FROM useful_word_records WHERE kind=? AND id=?').get(kind,id));
  const put = (kind,id,patient,value) => db.prepare(`INSERT INTO useful_word_records VALUES (?,?,?,?)
    ON CONFLICT(kind,id) DO UPDATE SET payload=excluded.payload`).run(kind,id,patient,seal(value));
  const list = (kind,patient) => db.prepare('SELECT payload FROM useful_word_records WHERE kind=? AND patient_id=?').all(kind,patient).map(open);
  const wav = value => {
    if (typeof value !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) fail(400,'Choose a WAV recording.');
    const bytes = Buffer.from(value,'base64');
    if (bytes.length < 44 || bytes.length > 12*1024*1024 || bytes.toString('ascii',0,4) !== 'RIFF' || bytes.toString('ascii',8,12) !== 'WAVE') fail(400,'Choose a WAV recording up to 12 MB.');
    return bytes;
  };
  const therapist = u => { if (u.role !== 'therapist') fail(403,'Only the assigned therapist can do this.'); };
  // The parent's signed care consent covers word practice, so there is no separate form.
  const parentConsented = patientId => !!db.prepare("SELECT 1 FROM consents WHERE patient_id=? AND status='approved' AND version=?").get(patientId, consentVersion);
  const summary = a => ({ id:a.id, wordId:a.wordId, word:a.word, date:a.date, transcript:a.transcript,
    transcriptionStatus:a.transcriptionStatus, feedback:a.feedback, hasFeedbackAudio:!!a.feedbackAudio, reviewed:a.reviewed });
  const pending = new Set();
  async function transcribe(patientId, attempt) {
    try {
      const transcript = await transcriber.suggest(Buffer.from(attempt.audio,'base64'));
      const current = get('attempt',attempt.id);
      if (!current) return;
      current.transcript = typeof transcript === 'string' && transcript.trim() ? transcript.slice(0,4000) : null;
      current.transcriptionStatus = current.transcript ? 'suggested' : 'failed';
      put('attempt',current.id,patientId,current);
    } catch {
      const current = get('attempt',attempt.id);
      if (current) { current.transcriptionStatus='failed'; current.transcript=null; put('attempt',current.id,patientId,current); }
    }
  }
  return async function route(req,res,url,u) {
    const match = url.pathname.match(/^\/api\/useful-words\/patients\/([^/]+)(?:\/(enrollment|words|attempts)(?:\/([^/]+)(?:\/(audio|review|feedback))?)?)?$/);
    if (!match) return false;
    const [, patientId, action, itemId, subaction] = match;
    const patient = findUser(patientId);
    const assigned = patient && patient.role === 'patient' && patient.therapist_id && findUser(patient.therapist_id)?.status === 'active';
    const linked = u.id === patientId && u.role === 'patient' || u.role === 'therapist' && u.id === patient?.therapist_id || u.role === 'parent' && u.id === patient?.parent_id;
    if (!assigned || !linked) fail(403,'This child is not paired with your account.');
    const enrollment = get('enrollment',patientId);
    const requireEnrollment = () => { if (!enrollment || new Date(enrollment.birthDate).getTime() > Date.now()) fail(409,'Therapist enrollment is required.');
      const birth=new Date(enrollment.birthDate), today=new Date();
      const age=today.getUTCFullYear()-birth.getUTCFullYear()-(today.toISOString().slice(5,10)<enrollment.birthDate.slice(5,10)?1:0);
      if (age >= 17) fail(409,'This feature is for children under 17.'); };
    const consent = parentConsented(patientId);
    if (!action && req.method === 'GET') {
      const words = list('word',patientId).filter(w => w.therapistId === patient.therapist_id);
      json(res,200,{ enrollment:!!enrollment, consent, mockTranscription:transcriber instanceof UnavailableTranscriber,
        words:words.map(({exampleAudio,...w})=>w), attempts:list('attempt',patientId).sort((a,b)=>b.date.localeCompare(a.date)).map(summary) }); return true;
    }
    if (action === 'enrollment' && req.method === 'PUT') {
      therapist(u); const b=await body(req);
      const birthDate=text(b.birthDate,'Date of birth',10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(birthDate) || !Number.isFinite(Date.parse(birthDate)) || new Date(birthDate).toISOString().slice(0,10)!==birthDate || Date.parse(birthDate)>Date.now()) fail(400,'Enter a valid date of birth.');
      const cutoff=new Date(); cutoff.setUTCFullYear(cutoff.getUTCFullYear()-17);
      if (Date.parse(birthDate)<=cutoff.getTime() || b.usesSpeech!==true || b.therapistSelectedGoals!==true) fail(400,'Enrollment requires a child under 17 who uses speech and has therapist-selected goals.');
      put('enrollment',patientId,patientId,{birthDate,therapistId:u.id}); json(res,200,{ok:true}); return true;
    }
    requireEnrollment();
    if (action === 'words' && !itemId && req.method === 'POST') {
      therapist(u); const b=await body(req,19*1024*1024);
      wav(b.exampleAudio);
      const picture=text(b.picture,'Picture',2000000);
      if (!/^data:image\/(png|jpeg);base64,[A-Za-z0-9+/]+={0,2}$/.test(picture)) fail(400,'Choose a PNG or JPEG picture up to 1.5 MB.');
      const word={id:randomUUID(),word:text(b.word,'Word',80),picture,exampleAudio:b.exampleAudio,therapistId:u.id};
      put('word',word.id,patientId,word); json(res,201,{id:word.id}); return true;
    }
    if (action === 'words' && subaction === 'audio' && req.method === 'GET') {
      const word=get('word',itemId);
      if (!word || word.therapistId!==patient.therapist_id || !list('word',patientId).some(w=>w.id===itemId)) fail(404,'Word not found.');
      json(res,200,{audio:word.exampleAudio}); return true;
    }
    if (action === 'attempts' && !itemId && req.method === 'POST') {
      if (u.id!==patientId) fail(403,'Only the child can submit their attempt.');
      if (!consent) fail(409,'A parent must sign consent before recording or sending.');
      const b=await body(req,17*1024*1024); const id=text(b.id,'Submission ID',80);
      const audio=wav(b.audio), digest=createHash('sha256').update(audio).digest('hex');
      const existing=get('attempt',id);
      if (existing) {
        if (!list('attempt',patientId).some(a=>a.id===id) || existing.wordId!==b.wordId || existing.digest!==digest) fail(409,'Submission ID conflicts with another attempt.');
        json(res,200,{id,status:'delivered'}); return true;
      }
      const word=list('word',patientId).find(w=>w.id===b.wordId && w.therapistId===patient.therapist_id);
      if (!word) fail(400,'Choose a word assigned by your current therapist.');
      const attempt={id,wordId:word.id,word:word.word,audio:b.audio,digest,date:new Date().toISOString(),transcript:null,transcriptionStatus:'pending',feedback:'',feedbackAudio:null,reviewed:false};
      // Persist and acknowledge before recognition; a stalled recognizer cannot
      // hold the delivery response or replace the submitted bytes.
      put('attempt',id,patientId,attempt); json(res,201,{id,status:'delivered'});
      const job=transcribe(patientId,attempt); pending.add(job); job.finally(()=>pending.delete(job)); return true;
    }
    if (action === 'attempts' && itemId) {
      const attempt=list('attempt',patientId).find(a=>a.id===itemId);
      if (!attempt) fail(404,'Attempt not found.');
      if (subaction === 'audio' && req.method === 'GET') { therapist(u); json(res,200,{audio:attempt.audio}); return true; }
      if (subaction === 'feedback' && req.method === 'GET') { json(res,200,{audio:attempt.feedbackAudio}); return true; }
      if (subaction === 'review' && req.method === 'PUT') {
        therapist(u); const b=await body(req,17*1024*1024);
        if (typeof b.feedback!=='string' || b.feedback.length>2000 || typeof b.reviewed!=='boolean') fail(400,'Enter feedback up to 2000 characters and a review status.');
        if (b.feedbackAudio) wav(b.feedbackAudio);
        put('attempt',attempt.id,patientId,{...attempt,feedback:b.feedback.trim(),feedbackAudio:b.preserveAudio===true && !b.feedbackAudio?attempt.feedbackAudio:b.feedbackAudio || null,reviewed:b.reviewed}); json(res,200,{ok:true}); return true;
      }
    }
    fail(405,'Method not allowed.');
  };
}
