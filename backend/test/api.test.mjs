import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/server.mjs';
import { hashPassword } from '../src/auth.mjs';
import { now, consentVersion } from '../src/db.mjs';

const password='TestPassword!2026';
const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=';
async function fixture(t, options = {}) {
  const dir=await mkdtemp(join(tmpdir(),'melo-api-'));
  const app=createApp({dataDir:dir, ...options});
  await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${app.server.address().port}`;
  t.after(async()=>{await app.motor.waitForIdle();app.server.closeAllConnections();await new Promise(resolve=>app.server.close(resolve));app.db.close();await rm(dir,{recursive:true,force:true});});
  const hash=await hashPassword(password);
  const add=(role,status='active')=>{const id=randomUUID();app.db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES(?,?,?,?,?,?,?)').run(id,`${role} Test`,`${id}@test.example`,hash,role,status,now());return app.db.prepare('SELECT * FROM users WHERE id=?').get(id);};
  const call=async(path,method='GET',body,token,headers={})=>{
    const response=await fetch(base+'/api'+path,{method,headers:{...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`} : {}),...headers},body:body?JSON.stringify(body):undefined});
    const data=response.headers.get('content-type')?.startsWith('application/json')?await response.json():await response.arrayBuffer();return {status:response.status,data,headers:response.headers};
  };
  const login=async account=>{const r=await call('/auth/login','POST',{email:account.email,password,client:'mobile'});assert.equal(r.status,200);return r.data.token;};
  return {...app,dir,base,add,call,login};
}

test('authentication, pending approval, role escalation, session revocation and CSRF',async t=>{
  const f=await fixture(t);const admin=f.add('admin'),therapist=f.add('therapist','pending'),patient=f.add('patient');
  assert.equal((await f.call('/overview')).status,401);
  assert.equal((await f.call('/auth/register','POST',{role:'admin',name:'Bad',email:'bad@test.example',password})).status,400);
  assert.equal((await f.call('/auth/login','POST',{email:therapist.email,password})).status,403);
  const at=await f.login(admin),pt=await f.login(patient);
  assert.equal((await f.call('/overview','GET',undefined,pt)).status,403);
  assert.equal((await f.call(`/users/${therapist.id}`,'PATCH',{status:'active'},pt)).status,403);
  assert.equal((await f.call(`/users/${therapist.id}`,'PATCH',{status:'active'},at,{Origin:'https://untrusted.example'})).status,403);
  assert.equal((await f.call(`/users/${therapist.id}`,'PATCH',{status:'active'},at)).status,200);
  const tt=await f.login(therapist);
  assert.equal((await f.call('/auth/me','GET',undefined,tt)).status,200);
  assert.equal((await f.call(`/users/${therapist.id}`,'PATCH',{status:'disabled'},at)).status,200);
  assert.equal((await f.call('/auth/me','GET',undefined,tt)).status,401);
  const overview=await f.call('/overview','GET',undefined,at);assert.equal(overview.status,200);assert.ok(!JSON.stringify(overview.data).includes('password_hash'));
  const webLogin=await f.call('/auth/login','POST',{email:admin.email,password});assert.ok(webLogin.headers.get('set-cookie').includes('HttpOnly'));assert.ok(webLogin.headers.get('set-cookie').includes('SameSite=Strict'));assert.equal(webLogin.data.token,undefined);
  assert.equal((await f.call('/auth/logout','POST',{},pt)).status,200);
  assert.equal((await f.call('/auth/me','GET',undefined,pt)).status,401);
});

test('patient assignment isolation, consent gating, plans, idempotent progress, recording access and review',async t=>{
  const f=await fixture(t);const admin=f.add('admin'),therapist=f.add('therapist'),other=f.add('therapist'),patient=f.add('patient'),otherPatient=f.add('patient');
  const at=await f.login(admin),tt=await f.login(therapist),ot=await f.login(other),pt=await f.login(patient),op=await f.login(otherPatient);
  const patientPath=`/patients/${patient.id}`;
  assert.equal((await f.call(patientPath,'GET',undefined,tt)).status,403);
  assert.equal((await f.call(`${patientPath}/assignment`,'PUT',{therapistId:patient.id},at)).status,400);
  assert.equal((await f.call(`${patientPath}/assignment`,'PUT',{therapistId:therapist.id},at)).status,200);
  assert.equal((await f.call('/patients','GET',undefined,tt)).data.patients.length,1);
  assert.equal((await f.call(patientPath,'GET',undefined,ot)).status,403);
  assert.equal((await f.call(patientPath,'GET',undefined,op)).status,403);
  const plan={title:'Practice plan',exercises:['humming','breathing'],sessionsPerDay:2,notes:'Synthetic test plan'};
  assert.equal((await f.call(`${patientPath}/plans`,'POST',plan,tt)).status,409);
  const forms={age:30,demographic:'Synthetic demographic data',clinical:'Synthetic clinical data'};
  assert.equal((await f.call(`${patientPath}/forms`,'PUT',forms,tt)).status,409);
  const consent={version:consentVersion,signerName:patient.name,signaturePng:png,checks:{adult:true,participation:true,dataSharing:true,analysis:false}};
  assert.equal((await f.call(`${patientPath}/consent`,'POST',{...consent,checks:{...consent.checks,adult:false}},pt)).status,400);
  assert.equal((await f.call(`${patientPath}/consent`,'POST',consent,pt)).status,201);
  assert.equal((await f.call(`${patientPath}/consent`,'POST',consent,pt)).status,409);
  assert.equal((await f.call(`${patientPath}/approve-consent`,'POST',{paperCopy:true},pt)).status,403);
  assert.equal((await f.call(`${patientPath}/approve-consent`,'POST',{paperCopy:false},tt)).status,400);
  assert.equal((await f.call(`${patientPath}/approve-consent`,'POST',{paperCopy:true},tt)).status,200);
  assert.equal((await f.call(`${patientPath}/plans`,'POST',plan,tt)).status,409);
  assert.equal((await f.call(`${patientPath}/forms`,'PUT',forms,tt)).status,200);
  assert.equal((await f.call(patientPath,'GET',undefined,pt)).data.forms,null);
  assert.equal((await f.call(`${patientPath}/plans`,'POST',{...plan,exercises:['invented']},tt)).status,400);
  const created=await f.call(`${patientPath}/plans`,'POST',plan,tt);assert.equal(created.status,201);
  const progress={id:randomUUID(),planId:created.data.plan.id,exerciseId:'humming',minutes:5,completedAt:now()};
  assert.equal((await f.call(`${patientPath}/progress`,'POST',progress,pt)).status,200);
  assert.equal((await f.call(`${patientPath}/progress`,'POST',progress,pt)).status,200);
  assert.equal((await f.call(`${patientPath}/progress`,'POST',{...progress,minutes:10},pt)).status,409);
  assert.equal((await f.call(patientPath,'GET',undefined,pt)).data.progress.length,1);
  assert.equal((await f.call(`${patientPath}/progress`,'POST',{...progress,id:randomUUID(),completedAt:'2099-01-01T00:00:00Z'},pt)).status,400);
  const wav=Buffer.alloc(100);wav.write('RIFF');wav.writeUInt32LE(92,4);wav.write('WAVE',8);wav.write('fmt ',12);wav.writeUInt32LE(16,16);wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(44100,24);wav.writeUInt32LE(88200,28);wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(56,40);
  const recording={id:randomUUID(),planId:created.data.plan.id,exerciseId:'humming',durationSeconds:1,audio:wav.toString('base64')};
  assert.equal((await f.call(`${patientPath}/recordings`,'POST',{...recording,audio:'bm90IGF1ZGlv'},pt)).status,400);
  assert.equal((await f.call(`${patientPath}/recordings`,'POST',recording,pt)).status,201);
  assert.equal((await f.call(`${patientPath}/recordings`,'POST',recording,pt)).status,200);
  assert.equal((await f.call(`/recordings/${recording.id}/audio`,'GET',undefined,ot)).status,403);
  const audio=await f.call(`/recordings/${recording.id}/audio`,'GET',undefined,tt);assert.equal(audio.status,200);assert.equal(audio.data.byteLength,100);
  assert.ok(f.db.prepare("SELECT 1 FROM audit WHERE action='Played recording' AND actor_id=? AND detail=?").get(therapist.id,recording.id));
  assert.equal((await f.call(`/recordings/${recording.id}/review`,'POST',{note:'Reviewed test recording'},tt)).status,200);
  assert.equal((await f.call(patientPath,'GET',undefined,pt)).data.recordings[0].review_note,'Reviewed test recording');
  // Reassignment revokes the previous therapist's access immediately.
  assert.equal((await f.call(`${patientPath}/assignment`,'PUT',{therapistId:other.id},at)).status,200);
  assert.equal((await f.call(patientPath,'GET',undefined,tt)).status,403);
  assert.equal((await f.call(`/recordings/${recording.id}/audio`,'GET',undefined,tt)).status,403);
  assert.equal((await f.call(patientPath,'GET',undefined,ot)).status,200);
});

test('registration normalization, duplicate email, password changes and rate limiting',async t=>{
  const f=await fixture(t);
  const account={name:'Patient Example',email:'PERSON@Test.Example',password,role:'patient'};
  const created=await f.call('/auth/register','POST',account);assert.equal(created.status,201);assert.equal(created.data.user.email,'person@test.example');assert.equal(created.data.user.password_hash,undefined);
  assert.equal((await f.call('/auth/register','POST',{...account,email:'person@test.example'})).status,409);
  const pt=await f.login(created.data.user);
  assert.equal((await f.call('/auth/password','POST',{currentPassword:'wrong',password:'NewPassword!2026'},pt)).status,400);
  assert.equal((await f.call('/auth/password','POST',{currentPassword:password,password:'NewPassword!2026'},pt)).status,200);
  assert.equal((await f.call('/auth/me','GET',undefined,pt)).status,401);
  assert.equal((await f.call('/auth/login','POST',{email:account.email,password:'NewPassword!2026'})).status,200);
  for(let i=0;i<5;i++)assert.equal((await f.call('/auth/login','POST',{email:'unknown@example.test',password:'incorrect'})).status,401);
  assert.equal((await f.call('/auth/login','POST',{email:'unknown@example.test',password:'incorrect'})).status,429);
});

test('persistent database survives restart and static files do not expose runtime data',async t=>{
  const f=await fixture(t);const admin=f.add('admin');const token=await f.login(admin);
  assert.equal((await fetch(f.base+'/data/melo.sqlite')).status,404);
  assert.equal((await fetch(f.base+'/../backend/src/server.mjs')).status,404);
  const root=await fetch(f.base+'/');assert.equal(root.status,200);assert.ok(root.headers.get('content-security-policy').includes("frame-ancestors 'none'"));
  const second=createApp({dataDir:f.dir});
  assert.equal(second.db.prepare('SELECT name FROM users WHERE id=?').get(admin.id).name,admin.name);
  assert.equal(second.db.prepare('SELECT COUNT(*) AS n FROM sessions').get().n,1);
  second.db.close();
  assert.equal((await f.call('/auth/me','GET',undefined,token)).status,200);
});

test('administrator-created therapists start approved, self-registered ones wait', async t => {
  const f = await fixture(t);
  const admin = f.add('admin');
  const at = await f.login(admin);
  const details = { role: 'therapist', name: 'Created Therapist', clinic: 'Clinic', registration: 'REG-1', password };
  const created = await f.call('/users', 'POST', { ...details, email: 'created@test.example' }, at);
  assert.equal(created.status, 201);
  assert.equal(created.data.user.status, 'active');
  const registered = await f.call('/auth/register', 'POST', { ...details, email: 'registered@test.example' });
  assert.equal(registered.status, 201);
  assert.equal(registered.data.user.status, 'pending');
});

test('child motor practice: consent, photo integrity, real analysis seam, review and reassignment', async t => {
  let calls=0;
  const report={imageQuality:'usable',observations:'Three lines are visible.',alignment:'developing',formation:'emerging',spacing:'not_assessable',suggestion:'Try one short line, then rest.',model:'test-vision',generatedAt:now()};
  const f=await fixture(t,{motorAnalyzer:async()=>{calls++;return report;}});
  const admin=f.add('admin'),therapist=f.add('therapist'),other=f.add('therapist'),patient=f.add('patient'),outsider=f.add('patient');
  const at=await f.login(admin),tt=await f.login(therapist),ot=await f.login(other),pt=await f.login(patient),out=await f.login(outsider);
  const path=`/patients/${patient.id}`;
  await f.call(`${path}/assignment`,'PUT',{therapistId:therapist.id},at);
  // A real 128x128 PNG is generated below by the test image helper.
  const photo=testPhoto();
  const payload={id:randomUUID(),planId:'missing',exerciseId:'motor-lines',photo:photo.toString('base64'),practiceDay:now().slice(0,10)};
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',payload,pt)).status,409);
  const priorConsent=randomUUID();
  f.db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES(?,?,?,?,?,?,?,?)').run(priorConsent,patient.id,'CONNECTED-DEMO-1','Earlier signer',png,JSON.stringify({analysis:true}),'approved',now());
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',payload,pt)).status,409);
  await f.call(`${path}/consent`,'POST',{version:consentVersion,signerName:'Synthetic Parent',signaturePng:png,checks:{adult:true,participation:true,dataSharing:true,analysis:true}},pt);
  assert.equal(f.db.prepare('SELECT COUNT(*) AS n FROM consents WHERE patient_id=?').get(patient.id).n,2);
  await f.call(`${path}/approve-consent`,'POST',{paperCopy:true},tt);
  assert.equal((await f.call(`${path}/forms`,'PUT',{age:7,demographic:'Child with guardian',clinical:'Short supervised practice'},tt)).status,200);
  const plan=await f.call(`${path}/plans`,'POST',{title:'Daily little practice',exercises:['motor-lines','motor-shapes','motor-letter'],sessionsPerDay:1,notes:'Rest when tired'},tt);
  assert.equal(plan.status,201);payload.planId=plan.data.plan.id;
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',{...payload,photo:'bm90IGEgcmVhbCBwaG90bw=='},pt)).status,400);
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',{...payload,practiceDay:'2099-01-01'},pt)).status,400);
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',{...payload,exerciseId:'humming'},pt)).status,400);
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',payload,tt)).status,403);
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',payload,out)).status,403);
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',payload,pt)).status,201);
  await f.motor.waitForIdle();assert.equal(calls,1);
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',payload,pt)).status,200);
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',{...payload,practiceDay:new Date(Date.now()-86400000).toISOString().slice(0,10)},pt)).status,409);
  const get=await f.call(path,'GET',undefined,tt);
  assert.equal(get.data.progress.length,1);assert.equal(get.data.progress[0].minutes,1);assert.equal(get.data.motorSubmissions.length,1);assert.equal(get.data.motorSubmissions[0].analysis_status,'ready');assert.deepEqual(get.data.motorSubmissions[0].report,report);
  assert.equal((await f.call(path,'GET',undefined,pt)).data.motorSubmissions[0].report,null);
  const media=`/motor-submissions/${payload.id}/photo`;
  assert.equal((await f.call(media)).status,401);
  assert.equal((await f.call(media,'GET',undefined,ot)).status,403);
  const original=await f.call(media,'GET',undefined,tt);assert.equal(original.status,200);assert.deepEqual(Buffer.from(original.data),photo);
  assert.equal((await f.call(`/motor-submissions/${payload.id}/review`,'POST',{note:'Nice practice. Let us work on one line next time.'},pt)).status,403);
  assert.equal((await f.call(`/motor-submissions/${payload.id}/review`,'POST',{note:'Nice practice. Let us work on one line next time.'},tt)).status,200);
  assert.ok((await f.call(path,'GET',undefined,pt)).data.motorSubmissions[0].review_note);
  const restarted=createApp({dataDir:f.dir});assert.equal(restarted.motor.summaries(patient.id,'therapist')[0].report.model,'test-vision');restarted.db.close();
  await f.call(`${path}/assignment`,'PUT',{therapistId:other.id},at);
  assert.equal((await f.call(media,'GET',undefined,tt)).status,403);
  assert.equal((await f.call(media,'GET',undefined,ot)).status,200);
});

test('motor analysis failure keeps original and allows retry; declining analysis never invokes model',async t=>{
  let calls=0;
  const f=await fixture(t,{motorAnalyzer:async()=>{calls++;throw new Error('Model offline');}});
  const therapist=f.add('therapist'),patient=f.add('patient');
  f.db.prepare('UPDATE users SET therapist_id=? WHERE id=?').run(therapist.id,patient.id);
  const tt=await f.login(therapist),pt=await f.login(patient),path=`/patients/${patient.id}`;
  const consentId=randomUUID(),planId=randomUUID();
  f.db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES(?,?,?,?,?,?,?,?)').run(consentId,patient.id,consentVersion,'Parent',png,JSON.stringify({analysis:true}),'approved',now());
  f.db.prepare('INSERT INTO plans VALUES(?,?,?,?,?,?,?,?,?)').run(planId,patient.id,therapist.id,consentId,'Daily practice',JSON.stringify(['motor-lines']),1,'',now());
  const payload={id:randomUUID(),planId,exerciseId:'motor-lines',photo:testPhoto().toString('base64'),practiceDay:now().slice(0,10)};
  assert.equal((await f.call(`${path}/motor-submissions`,'POST',payload,pt)).status,201);await f.motor.waitForIdle();
  let entry=(await f.call(path,'GET',undefined,tt)).data.motorSubmissions[0];assert.equal(entry.analysis_status,'unavailable');assert.equal(entry.report,null);
  assert.equal((await f.call(`/motor-submissions/${payload.id}/analyze`,'POST',{},tt)).status,202);await f.motor.waitForIdle();assert.equal(calls,2);
  f.db.prepare('UPDATE consents SET checks=? WHERE id=?').run(JSON.stringify({analysis:false}),consentId);
  const declined={...payload,id:randomUUID()};await f.call(`${path}/motor-submissions`,'POST',declined,pt);await f.motor.waitForIdle();assert.equal(calls,2);
  entry=(await f.call(path,'GET',undefined,tt)).data.motorSubmissions[0];assert.equal(entry.analysis_status,'declined');
  assert.equal((await f.call(`/motor-submissions/${declined.id}/analyze`,'POST',{},tt)).status,409);
  assert.equal((await f.call(`/motor-submissions/${declined.id}/photo`,'GET',undefined,tt)).status,200);
});

function testPhoto() { return Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAIAAABMXPacAAABC0lEQVR4nO3TQREAAAjDMPybBhk8mkjYrrO8Gvs7IE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFOCANgU4oE0BDmhTgAPaFLC/DpTpSzJeKQ2cAAAAAElFTkSuQmCC','base64'); }
