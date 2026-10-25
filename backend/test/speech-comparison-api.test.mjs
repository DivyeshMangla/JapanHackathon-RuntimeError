import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID, createHash } from 'node:crypto';
import { createApp } from '../src/server.mjs';
import { hashPassword } from '../src/auth.mjs';
import { consentVersion, now } from '../src/db.mjs';
import { hostedAnalysisDisclosureVersion } from '../src/hosted-analysis.mjs';
import { toneWav } from './fixtures/audio.mjs';

const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=';

test('therapist can generate a report for a saved attempt after permission is granted',async t=>{
  let calls=0,finish;
  const held=new Promise(resolve=>{finish=resolve;});
  const f=await speechFixture(t,{externalProvider:'groq',suggest:async()=>{calls++;return held;}});
  const submitted=await f.submit();
  const attemptPath=`${f.path}/attempts/${submitted.value.id}`;
  assert.equal((await f.call(`${attemptPath}/analyze`,'POST',undefined,f.tt)).status,409);
  assert.equal(calls,0);
  await f.grant(true);
  assert.equal((await f.call(`${attemptPath}/analyze`,'POST',undefined,f.pt)).status,403);
  assert.equal((await f.call(`${attemptPath}/analyze`,'POST',undefined,f.ct)).status,403);
  await f.call(`${attemptPath}/review`,'PUT',{feedback:'Keep practising',reviewed:true,analysisCorrection:'Clinician note'},f.tt);
  try {
    assert.equal((await f.call(`${attemptPath}/analyze`,'POST',undefined,f.tt)).status,202);
    assert.equal((await f.call(`${attemptPath}/analyze`,'POST',undefined,f.tt)).status,202);
    assert.equal(calls,1);
  } finally { finish('help'); }
  await f.wordRoutes.waitForIdle();
  assert.equal(calls,2);
  const attempt=(await f.call(f.path,'GET',undefined,f.tt)).value.attempts[0];
  assert.equal(attempt.analysisReport.processingStatus,'complete');
  assert.equal(attempt.analysisReport.recognizedWord,'help');
  assert.equal(attempt.reviewed,true);
  assert.equal(attempt.feedback,'Keep practising');
  assert.equal(attempt.analysisCorrection.text,'Clinician note');
  assert.equal((await f.call(`${attemptPath}/audio`,'GET',undefined,f.tt)).value.audio,f.childAudio.toString('base64'));
});

test('failed speech recognition can be retried against the saved recording',async t=>{
  let failing=true;
  const f=await speechFixture(t,{suggest:async()=>{if(failing) throw Error('Offline');return 'help';}});
  const submitted=await f.submit();await f.wordRoutes.waitForIdle();
  assert.equal((await f.call(f.path,'GET',undefined,f.tt)).value.attempts[0].transcriptionStatus,'failed');
  failing=false;
  assert.equal((await f.call(`${f.path}/attempts/${submitted.value.id}/analyze`,'POST',undefined,f.tt)).status,202);
  await f.wordRoutes.waitForIdle();
  assert.equal((await f.call(f.path,'GET',undefined,f.tt)).value.attempts[0].analysisReport.processingStatus,'complete');
});
async function speechFixture(t, transcriber, localAnalysis=true) {
  const dataDir=await mkdtemp(join(tmpdir(),'melo-speech-api-'));
  const app=createApp({dataDir,transcriber});
  await new Promise(resolve=>app.server.listen(0,'127.0.0.1',resolve));
  t.after(async()=>{await app.wordRoutes.waitForIdle();await app.motor.waitForIdle();app.server.closeAllConnections();await new Promise(resolve=>app.server.close(resolve));app.db.close();await rm(dataDir,{recursive:true,force:true});});
  const password='SpeechTestPassword!2026',hash=await hashPassword(password);
  const add=role=>{
    const id=randomUUID();app.db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES(?,?,?,?,?,?,?)').run(id,`${role} test`,`${id}@test.invalid`,hash,role,'active',now());
    return app.db.prepare('SELECT * FROM users WHERE id=?').get(id);
  };
  const child=add('patient'),parent=add('parent'),therapist=add('therapist');
  app.db.prepare('UPDATE users SET parent_id=?,therapist_id=? WHERE id=?').run(parent.id,therapist.id,child.id);
  app.db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES(?,?,?,?,?,?,?,?)').run(randomUUID(),child.id,consentVersion,'Guardian',png,JSON.stringify({adult:true,participation:true,dataSharing:true,analysis:localAnalysis}),'approved',now());
  const call=async(path,method='GET',value,token)=>{
    const response=await fetch(`http://127.0.0.1:${app.server.address().port}/api${path}`,{method,headers:{...(token?{Authorization:`Bearer ${token}`} : {}),...(value?{'Content-Type':'application/json'}:{})},body:value?JSON.stringify(value):undefined});
    return {status:response.status,value:await response.json()};
  };
  const login=async account=>(await call('/auth/login','POST',{email:account.email,password,client:'mobile'})).value.token;
  const ct=await login(child),pt=await login(parent),tt=await login(therapist),path=`/useful-words/patients/${child.id}`;
  const reference=toneWav(),childAudio=toneWav({duration:0.8,amplitude:0.3});
  const word=(await call(`${path}/words`,'POST',{word:'help',picture:`data:image/png;base64,${png}`,exampleAudio:reference.toString('base64')},tt)).value.id;
  const grant=allowed=>call(`/patients/${child.id}/hosted-analysis`,'PUT',{allowed,adultConfirmed:true,disclosureVersion:hostedAnalysisDisclosureVersion},pt);
  const submit=()=>call(`${path}/attempts`,'POST',{id:randomUUID(),wordId:word,audio:childAudio.toString('base64')},ct);
  return {...app,call,child,parent,therapist,ct,pt,tt,path,reference,childAudio,word,grant,submit};
}

test('hosted recognition needs separate permission and preserves immutable independently recognized reference',async t=>{
  const sent=[];
  const f=await speechFixture(t,{externalProvider:'groq',modelId:'whisper-large-v3',language:'en',suggest:async audio=>{sent.push(Buffer.from(audio));return sent.length===1?'held':'help';}});
  assert.equal((await f.submit()).status,201);await f.wordRoutes.waitForIdle();assert.equal(sent.length,0);
  let attempts=(await f.call(f.path,'GET',undefined,f.tt)).value.attempts;
  assert.equal(attempts[0].transcriptionStatus,'hosted_consent_required');
  assert.equal((await f.grant(true)).status,200);
  const submitted=await f.submit();assert.equal(submitted.status,201);await f.wordRoutes.waitForIdle();
  assert.equal(sent.length,2);assert.deepEqual(sent[0],f.childAudio);assert.deepEqual(sent[1],f.reference);
  attempts=(await f.call(f.path,'GET',undefined,f.tt)).value.attempts;
  const attempt=attempts.find(entry=>entry.id===submitted.value.id),report=attempt.analysisReport;
  assert.equal(report.recognizedWord,'held');assert.equal(report.textSimilarity.textSimilarityPercent,75);
  assert.equal(report.reference.recognizedText,'help');assert.equal(report.reference.needsReview,false);
  assert.equal(report.referenceTranscriptComparison.textSimilarityPercent,75);
  assert.equal(report.reference.audioDigest,createHash('sha256').update(f.reference).digest('hex'));
  assert.equal(report.pronunciationAccuracy,null);assert.equal(report.audioComparison.durationRatio,1.6);
  f.db.prepare("DELETE FROM useful_word_records WHERE kind='word' AND id=?").run(f.word);
  const referencePath=`${f.path}/attempts/${attempt.id}/reference`;
  assert.deepEqual(Buffer.from((await f.call(referencePath,'GET',undefined,f.tt)).value.audio,'base64'),f.reference);
  assert.equal((await f.call(referencePath,'GET',undefined,f.ct)).status,403);
  assert.equal((await f.call(referencePath,'GET',undefined,f.pt)).status,403);
  assert.equal((await f.call(f.path,'GET',undefined,f.tt)).value.attempts.find(entry=>entry.id===attempt.id).analysisReport.reference.targetWord,'help');
});

test('separate hosted grant can permit analysis after optional local analysis was declined',async t=>{
  let calls=0;
  const f=await speechFixture(t,{externalProvider:'groq',suggest:async()=>{calls++;return 'help';}},false);
  assert.equal((await f.grant(true)).status,200);
  const submitted=await f.submit();await f.wordRoutes.waitForIdle();assert.equal(calls,2);
  assert.equal((await f.call(f.path,'GET',undefined,f.tt)).value.attempts.find(entry=>entry.id===submitted.value.id).transcriptionStatus,'suggested');
});

test('revoking online permission stops queued child and reference requests and discards unshared suggestions',async t=>{
  let finish,started,calls=0;
  const began=new Promise(resolve=>{started=resolve;});
  const held=new Promise(resolve=>{finish=resolve;});
  const f=await speechFixture(t,{externalProvider:'groq',suggest:()=>{calls++;started();return held;}});
  await f.grant(true);
  await f.submit();await began;await f.submit();
  assert.equal((await f.grant(false)).status,200);
  finish('help');await f.wordRoutes.waitForIdle();
  assert.equal(calls,1);
  for (const attempt of (await f.call(f.path,'GET',undefined,f.tt)).value.attempts) {
    assert.equal(attempt.transcriptionStatus,'hosted_consent_required');assert.equal(attempt.transcript,null);
    assert.equal(attempt.analysisReport.textSimilarity.textSimilarityPercent,null);
    assert.deepEqual(Buffer.from((await f.call(`${f.path}/attempts/${attempt.id}/audio`,'GET',undefined,f.tt)).value.audio,'base64'),f.childAudio);
  }
});
