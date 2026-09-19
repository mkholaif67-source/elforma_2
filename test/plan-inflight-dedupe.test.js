'use strict';
const assert = require('node:assert/strict');
const plan = require('../api/plan');
(async function () {
  let runs = 0;
  const profile = { age:30, height:180, weight:80 };
  const factory = async () => { runs++; await new Promise(r => setTimeout(r, 25)); return { ok:true }; };
  const tasks = Array.from({length:12}, () => plan._sharedCompute('plan','u-test',profile,{},factory));
  const results = await Promise.all(tasks);
  assert.equal(runs, 1, 'identical concurrent calculations must share one worker task');
  assert.equal(results.length, 12);
  assert.equal(plan._inFlightComputes.size, 0, 'completed task must not become a stale cache');
  await plan._sharedCompute('plan','u-test',profile,{},factory);
  assert.equal(runs, 2, 'a later request must run fresh');
  console.log('plan in-flight dedupe contracts passed');
})().catch(e => { console.error(e); process.exit(1); });
