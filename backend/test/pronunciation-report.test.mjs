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
