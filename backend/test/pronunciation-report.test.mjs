import test from 'node:test';
import assert from 'node:assert/strict';
import { pronunciationReport, recognizeWithDeadline } from '../src/pronunciation-report.mjs';

test('matching, differing and absent recognized text never becomes phonetic evidence or an accuracy score', () => {
  for (const [recognized,comparison] of [['help','same_text'],['water','different_text'],[null,'unavailable']]) {
    const report=pronunciationReport('help',recognized);
    assert.equal(report.textComparison,comparison);
    assert.equal(report.assessment,'Unable to assess reliably');
    assert.equal(report.pronunciationAccuracy,null);
    assert.equal(report.modelConfidence,null);
    assert.deepEqual(report.possibleSoundDifferences,[]);
  }
});

test('recognition deadline bounds a stalled integration',async()=>{
  // The test holds an event-loop reference; the production deadline is unrefed.
  const keepAlive=setTimeout(()=>{},1000);
  try { await assert.rejects(recognizeWithDeadline({suggest:()=>new Promise(()=>{})},Buffer.alloc(1),5),/timed out/); }
  finally { clearTimeout(keepAlive); }
});

import { createServer } from 'node:http';
import { spawnSync } from 'node:child_process';
import { createLocalTranscriber, createHostedTranscriber, createSpeechTranscriber, assessWordAudio } from '../src/pronunciation-report.mjs';
import { compareRecognizedText } from '../src/speech-comparison.mjs';
import { toneWav } from './fixtures/audio.mjs';

test('capture gates reject malformed, silent, too short, long and clipped input while retaining measurements', () => {
  const usable = assessWordAudio(toneWav());
  assert.equal(usable.eligibleForRecognition, true);
  assert.equal(usable.durationSeconds, 0.5);
  assert.equal(usable.sampleRate, 16000);
  for (const audio of [Buffer.alloc(100), toneWav({amplitude:0}), toneWav({duration:0.1}), toneWav({duration:31}), toneWav({clipped:true}), toneWav().subarray(0,70)]) {
    const quality = assessWordAudio(audio);
    assert.equal(quality.eligibleForRecognition, false);
    assert.ok(quality.reasons.length > 0);
  }
  const inconsistent = toneWav(); inconsistent.writeUInt32LE(100,28);
  assert.equal(assessWordAudio(inconsistent).status, 'unassessable');
});

test('text comparison tolerates punctuation and casing without inferring pronunciation', () => {
  const report = pronunciationReport('Help', ' help. ');
  assert.equal(report.textComparison,'same_text');
  assert.equal(report.pronunciationAccuracy,null);
});

test('local recognizer sends unprompted audio, validates responses, refuses redirects and keeps patient traffic local', async t => {
  let received, status=200, answer={text:'help'};
  const server=createServer(async(req,res)=>{
    const chunks=[];for await(const chunk of req)chunks.push(chunk);received=Buffer.concat(chunks);
    res.writeHead(status, status===302 ? {Location:'https://external.invalid/'} : {'Content-Type':'application/json'});
    res.end(JSON.stringify(answer));
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>{server.closeAllConnections();server.close();});
  const transcriber=createLocalTranscriber({endpoint:`http://127.0.0.1:${server.address().port}/inference`,model:'test-local',language:'en'});
  const original=toneWav(), duplicate=Buffer.from(original);
  assert.equal(await recognizeWithDeadline(transcriber,original),'help');
  assert.deepEqual(original,duplicate);
  assert.ok(received.includes(original));
  assert.ok(received.includes(Buffer.from('name="language"')));
  assert.equal(received.includes(Buffer.from('name="prompt"')),false);
  answer={text:42};await assert.rejects(()=>recognizeWithDeadline(transcriber,original),/Invalid recognition/);
  status=302;await assert.rejects(()=>recognizeWithDeadline(transcriber,original));
  assert.throws(()=>createLocalTranscriber({endpoint:'https://external.invalid/inference'}),/loopback/);
  assert.throws(()=>createLocalTranscriber({endpoint:'http://127.0.0.1:8080/inference',timeout:Infinity}),/timeout/);
});

test('mobile 44.1 kHz audio is converted locally for Whisper without changing the original', {skip:spawnSync('ffmpeg',['-version']).status!==0}, async t => {
  let received;
  const server=createServer(async(req,res)=>{const chunks=[];for await(const chunk of req)chunks.push(chunk);received=Buffer.concat(chunks);res.end(JSON.stringify({text:'help'}));});
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  t.after(()=>{server.closeAllConnections();server.close();});
  const original=toneWav({sampleRate:44100}), backup=Buffer.from(original);
  const transcriber=createLocalTranscriber({endpoint:`http://127.0.0.1:${server.address().port}/inference`});
  assert.equal(await recognizeWithDeadline(transcriber,original),'help');
  const start=received.indexOf(Buffer.from('RIFF'));
  assert.ok(start>0);
  assert.equal(received.readUInt32LE(start+24),16000);
  const uploadedWav=received.subarray(start,start+received.readUInt32LE(start+4)+8);
  assert.equal(uploadedWav.readUInt32LE(40),uploadedWav.length-44);
  const quality=assessWordAudio(uploadedWav);
  assert.equal(quality.eligibleForRecognition,true);
  assert.equal(quality.durationSeconds,0.5);
  assert.deepEqual(original,backup);
});

test('deadline actively cancels the integration signal',async()=>{
  let cancelled=false;
  const keepAlive=setTimeout(()=>{},1000);
  try {
    await assert.rejects(recognizeWithDeadline({suggest:(_audio,{signal})=>new Promise(()=>signal.addEventListener('abort',()=>{cancelled=true;}))},toneWav(),5),/timed out/);
    assert.equal(cancelled,true);
  } finally {clearTimeout(keepAlive);}
});

test('text similarity exposes edit evidence including repeats without labelling it pronunciation accuracy',()=>{
  const exact=compareRecognizedText('ＨＥＬＰ',' Help! ');
  assert.equal(exact.textSimilarityPercent,100);assert.equal(exact.wordEditDistance,0);
  const different=compareRecognizedText('help','held');
  assert.equal(different.characterEditDistance,1);assert.equal(different.wordEditDistance,1);assert.equal(different.textSimilarityPercent,75);
  assert.equal(compareRecognizedText('help','help help').wordEditDistance,1);
  assert.equal(compareRecognizedText('你好','你号').characterEditDistance,1);
  assert.equal(compareRecognizedText('help',null).textSimilarityPercent,null);
  assert.equal(compareRecognizedText('help','...').status,'unavailable');
  const report=pronunciationReport('help','held');
  assert.equal(report.textSimilarity.textSimilarityPercent,75);assert.equal(report.pronunciationAccuracy,null);
});

test('hosted Whisper sends only unprompted analysis audio to fixed Groq endpoint with server credential',async()=>{
  const original=toneWav(),backup=Buffer.from(original);let request;
  const transcriber=createHostedTranscriber({apiKey:'test-private-key',language:'en',transport:async(url,options)=>{
    request={url,...options};
    return new Response(JSON.stringify({text:'help',segments:[{start:0,end:0.5,no_speech_prob:0.7,avg_logprob:-1.2,compression_ratio:1.1}]}));
  }});
  assert.equal(transcriber.externalProvider,'groq');assert.equal(transcriber.modelId,'whisper-large-v3');
  const recognition=await recognizeWithDeadline(transcriber,original,undefined,{canUseHosted:()=>true});
  assert.equal(recognition.text,'help');assert.equal(recognition.evidence.warnings.length,2);
  assert.equal(request.url,'https://api.groq.com/openai/v1/audio/transcriptions');
  assert.equal(request.headers.Authorization,'Bearer test-private-key');assert.equal(request.redirect,'error');
  assert.deepEqual([...request.body.keys()].sort(),['file','language','model','response_format','temperature']);
  assert.equal(request.body.get('model'),'whisper-large-v3');assert.equal(request.body.get('response_format'),'verbose_json');
  assert.equal(request.body.get('file').name,'attempt.wav');
  assert.deepEqual(Buffer.from(await request.body.get('file').arrayBuffer()),original);
  assert.deepEqual(original,backup);assert.equal(request.signal.aborted,true);
});

test('hosted recognition rejects malformed output and capture failures without fabricated results',async()=>{
  let calls=0,answer={text:123};
  const transcriber=createHostedTranscriber({apiKey:'test',transport:async()=>{calls++;return new Response(JSON.stringify(answer));}});
  await assert.rejects(()=>recognizeWithDeadline(transcriber,toneWav({amplitude:0})),/eligible/);assert.equal(calls,0);
  await assert.rejects(()=>recognizeWithDeadline(transcriber,toneWav(),undefined,{canUseHosted:()=>true}),/Invalid recognition/);
  answer={text:'x'.repeat(4001)};await assert.rejects(()=>recognizeWithDeadline(transcriber,toneWav(),undefined,{canUseHosted:()=>true}),/Invalid recognition/);
  assert.equal(createHostedTranscriber({apiKey:''}),null);
  assert.equal(createSpeechTranscriber({provider:'groq',apiKey:''}),null);
  assert.throws(()=>createSpeechTranscriber({provider:'unknown'}),/PROVIDER/);
  assert.throws(()=>createHostedTranscriber({apiKey:'test',model:'unapproved'}),/supported/);
});

test('reference evidence identifies wrong expected-example transcript and exposes timing without acoustic scoring',()=>{
  const reference={wordId:'original-word',targetWord:'help',audioDigest:'original-digest',capturedAt:'2026-10-25T00:00:00Z',captureQuality:assessWordAudio(toneWav()),recognizedText:'water',recognitionStatus:'complete'};
  const report=pronunciationReport('help','held','complete',{reference,quality:assessWordAudio(toneWav({duration:1}))});
  assert.equal(report.reference.needsReview,true);assert.equal(report.reference.audioDigest,'original-digest');
  assert.equal(report.referenceTranscriptComparison.status,'different_text');
  assert.equal(report.audioComparison.status,'timing_only');assert.equal(report.audioComparison.durationRatio,2);
  assert.equal(report.audioComparison.pronunciationAccuracy,undefined);assert.equal(report.pronunciationAccuracy,null);
  assert.equal(report.reference.audio,undefined);
});


test('hosted recognition rechecks permission after local audio preparation and before transfer',async()=>{
  let calls=0;
  const transcriber=createHostedTranscriber({apiKey:'test',transport:async()=>{calls++;return new Response(JSON.stringify({text:'help'}));}});
  await assert.rejects(recognizeWithDeadline(transcriber,toneWav()),/permission/);
  await assert.rejects(recognizeWithDeadline(transcriber,toneWav(),undefined,{canUseHosted:()=>false}),/permission/);
  assert.equal(calls,0);
});
