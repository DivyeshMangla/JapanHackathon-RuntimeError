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
async function fixture(t) {
  const dir=await mkdtemp(join(tmpdir(),'melo-api-'));
  const app=createApp({dataDir:dir});
  await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
  const base=`http://127.0.0.1:${app.server.address().port}`;
  t.after(async()=>{app.server.closeAllConnections();await new Promise(resolve=>app.server.close(resolve));app.db.close();await rm(dir,{recursive:true,force:true});});
  const hash=await hashPassword(password);
  const add=(role,status='active')=>{const id=randomUUID();app.db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES(?,?,?,?,?,?,?)').run(id,`${role} Test`,`${id}@test.example`,hash,role,status,now());return app.db.prepare('SELECT * FROM users WHERE id=?').get(id);};
  const call=async(path,method='GET',body,token,headers={})=>{
    const response=await fetch(base+'/api'+path,{method,headers:{...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:`Bearer ${token}`} : {}),...headers},body:body?JSON.stringify(body):undefined});
    const data=response.headers.get('content-type')?.startsWith('application/json')?await response.json():await response.arrayBuffer();return {status:response.status,data,headers:response.headers};
  };
  const login=async account=>{const r=await call('/auth/login','POST',{email:account.email,password,client:'mobile'});assert.equal(r.status,200);return r.data.token;};
  const addExercise=(id,approved=true)=>app.db.prepare('INSERT INTO exercise_library VALUES (?,?,?)').run(id,JSON.stringify({id,title:`Exercise ${id}`,summary:'Synthetic exercise',approvedAt:approved?now():null,archived:false}),now());
  return {...app,dir,base,add,addExercise,call,login};
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
  for(const id of ['humming','breathing','reading']) f.addExercise(id);
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

test('exercise library, assignments, completions and voice samples follow role and assignment rules',async t=>{
  const f=await fixture(t);const admin=f.add('admin'),therapist=f.add('therapist'),other=f.add('therapist'),patient=f.add('patient'),stranger=f.add('patient');
  f.db.prepare('UPDATE users SET therapist_id=? WHERE id=?').run(therapist.id,patient.id);
  const at=await f.login(admin),tt=await f.login(therapist),ot=await f.login(other),pt=await f.login(patient),st=await f.login(stranger);
  const exercise={id:'ex-one',title:'First exercise',summary:'Synthetic',approvedAt:now(),archived:false};
  assert.equal((await f.call('/library/ex-one','PUT',exercise,tt)).status,403);
  assert.equal((await f.call('/library/ex-one','PUT',exercise,at)).status,200);
  assert.equal((await f.call('/library/ex-pending','PUT',{...exercise,id:'ex-pending',approvedAt:null},at)).status,200);
  assert.equal((await f.call('/library','GET',undefined,pt)).data.exercises.length,2);
  assert.equal((await f.call('/library/ex-one','PUT',{...exercise,id:'other'},at)).status,400);

  const base=`/patients/${patient.id}`;
  const assignment={id:'sched-1',patientId:patient.id,exerciseId:'ex-one',weekdays:[1,2,3]};
  assert.equal((await f.call(`${base}/assignments/sched-1`,'PUT',assignment,pt)).status,403);
  assert.equal((await f.call(`${base}/assignments/sched-1`,'PUT',assignment,ot)).status,403);
  assert.equal((await f.call(`${base}/assignments/sched-1`,'PUT',{...assignment,exerciseId:'ex-pending'},tt)).status,400);
  assert.equal((await f.call(`${base}/assignments/sched-1`,'PUT',assignment,tt)).status,200);
  assert.equal((await f.call(`${base}/assignments`,'GET',undefined,pt)).data.assignments.length,1);
  assert.equal((await f.call(`${base}/assignments`,'GET',undefined,st)).status,403);
  assert.equal((await f.call('/assignments','GET',undefined,tt)).status,403);
  assert.equal((await f.call('/assignments','GET',undefined,at)).data.assignments.length,1);

  const done={exerciseId:'ex-one',day:'2026-05-04',completedAt:'2026-05-04T09:00:00.000Z'};
  assert.equal((await f.call(`${base}/completions/c1`,'PUT',done,tt)).status,403);
  assert.equal((await f.call(`${base}/completions/c1`,'PUT',done,pt)).status,200);
  assert.equal((await f.call(`${base}/completions/c1`,'PUT',done,pt)).status,200);
  assert.equal((await f.call(`${base}/completions/c2`,'PUT',{...done,exerciseId:'missing'},pt)).status,400);
  const listed=await f.call(`${base}/completions?from=2026-05-01&to=2026-05-31`,'GET',undefined,tt);
  assert.deepEqual(listed.data.completions.map(c=>c.id),['c1']);
  assert.equal((await f.call(`${base}/completions?from=2026-06-01&to=2026-06-30`,'GET',undefined,tt)).data.completions.length,0);
  assert.equal((await f.call(`${base}/completions/c1`,'DELETE',undefined,pt)).status,200);
  assert.equal((await f.call(`${base}/completions`,'GET',undefined,pt)).data.completions.length,0);

  const wav=Buffer.concat([Buffer.from('RIFF'),Buffer.alloc(4),Buffer.from('WAVE'),Buffer.alloc(40)]).toString('base64');
  const meta={id:'rec-1',patientId:patient.id,kind:'practice',filePath:'/device/path.wav.vpa'};
  assert.equal((await f.call(`${base}/samples/rec-1`,'PUT',{meta,audio:Buffer.from('not audio').toString('base64')},pt)).status,400);
  assert.equal((await f.call(`${base}/samples/rec-1`,'PUT',{meta,audio:wav},pt)).status,201);
  assert.equal((await f.call(`${base}/samples/rec-1`,'PUT',{meta,audio:wav},pt)).status,200);
  const samples=await f.call(`${base}/samples`,'GET',undefined,tt);
  assert.equal(samples.data.samples[0].filePath,'');
  assert.equal((await f.call('/samples/rec-1/audio','GET',undefined,st)).status,403);
  assert.equal((await f.call('/samples/rec-1/audio','GET',undefined,ot)).status,403);
  const audio=await f.call('/samples/rec-1/audio','GET',undefined,tt);
  assert.equal(audio.status,200);assert.equal(audio.data.byteLength,wav.length*3/4-(wav.endsWith('==')?2:wav.endsWith('=')?1:0));
  assert.ok(f.db.prepare("SELECT COUNT(*) AS n FROM audit WHERE action='Played recording'").get().n>=1);
  assert.equal((await f.call('/samples','GET',undefined,at)).data.samples.length,1);
});

test('patients get sequential participant codes and administrators can assign a therapist at creation',async t=>{
  const f=await fixture(t);const admin=f.add('admin'),therapist=f.add('therapist');
  const at=await f.login(admin);
  const made=await f.call('/users','POST',{role:'patient',name:'New Patient',email:'new.patient@test.example',password,therapistId:therapist.id},at);
  assert.equal(made.status,201);assert.match(made.data.user.participant_code,/^P\d{3}$/);assert.equal(made.data.user.therapist_id,therapist.id);
  const second=await f.call('/users','POST',{role:'patient',name:'Second Patient',email:'second.patient@test.example',password},at);
  assert.notEqual(second.data.user.participant_code,made.data.user.participant_code);
  assert.equal((await f.call('/users','POST',{role:'patient',name:'Bad',email:'bad.assign@test.example',password,therapistId:made.data.user.id},at)).status,400);
});

test('diary entries, usage events and study settings follow role rules',async t=>{
  const f=await fixture(t);const admin=f.add('admin'),therapist=f.add('therapist'),other=f.add('therapist'),patient=f.add('patient'),stranger=f.add('patient');
  f.db.prepare('UPDATE users SET therapist_id=? WHERE id=?').run(therapist.id,patient.id);
  const at=await f.login(admin),tt=await f.login(therapist),ot=await f.login(other),pt=await f.login(patient),st=await f.login(stranger);
  const base=`/patients/${patient.id}`;
  const entry={id:'d1',patientId:patient.id,day:'2026-05-04T00:00:00.000',fatigue:3};
  assert.equal((await f.call(`${base}/diary/d1`,'PUT',entry,tt)).status,403);
  assert.equal((await f.call(`${base}/diary/d1`,'PUT',{...entry,patientId:stranger.id},pt)).status,400);
  assert.equal((await f.call(`${base}/diary/d1`,'PUT',entry,pt)).status,200);
  assert.equal((await f.call(`${base}/diary`,'GET',undefined,tt)).data.entries.length,1);
  assert.equal((await f.call(`${base}/diary`,'GET',undefined,ot)).status,403);
  assert.equal((await f.call('/diary','GET',undefined,at)).data.entries.length,1);
  assert.equal((await f.call(`${base}/diary/d1`,'DELETE',undefined,pt)).status,200);
  assert.equal((await f.call(`${base}/diary`,'GET',undefined,tt)).data.entries.length,0);

  const event={patientId:patient.id,at:'2026-05-04T09:00:00.000Z',action:'signIn',detail:''};
  assert.equal((await f.call(`${base}/usage`,'POST',event,tt)).status,403);
  assert.equal((await f.call(`${base}/usage`,'POST',{...event,at:'not a time'},pt)).status,400);
  assert.equal((await f.call(`${base}/usage`,'POST',event,pt)).status,201);
  assert.equal((await f.call(`${base}/usage`,'GET',undefined,tt)).data.events.length,1);
  assert.equal((await f.call(`${base}/usage`,'GET',undefined,st)).status,403);
  assert.equal((await f.call('/usage','GET',undefined,at)).data.events.length,1);

  assert.equal((await f.call('/study-settings','GET',undefined,pt)).data.settings,null);
  assert.equal((await f.call('/study-settings','PUT',{adherenceThreshold:0.7},tt)).status,403);
  assert.equal((await f.call('/study-settings','PUT',{adherenceThreshold:0.7},at)).status,200);
  assert.equal((await f.call('/study-settings','GET',undefined,tt)).data.settings.adherenceThreshold,0.7);
});
