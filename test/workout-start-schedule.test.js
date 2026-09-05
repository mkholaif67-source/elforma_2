'use strict';
const assert = require('assert');
const schedule = require('../lib/workout-schedule');

let passed = 0;
function check(name, fn) { fn(); passed++; console.log('  ✓ ' + name); }
function session(name) { return {name, exercises:[{name:name+' exercise'}]}; }
function rest() { return {name:'يوم راحة', isRest:true, exercises:[]}; }
function rawPpl() { return {plan:[rest(),session('Push'),rest(),session('Pull'),rest(),session('Legs'),rest()]}; }
function localNoon(y,m,d) { return Date.UTC(y,m-1,d,9); } // noon Cairo (+03)
const cairo = 3*3600000;

console.log('[new-user workout start]');
check('Saturday-based weekday contract is canonical', () => {
  assert.strictEqual(schedule.saturdayIndexForLocalDay(Date.UTC(2026,8,5)), 0);
  assert.strictEqual(schedule.saturdayIndexForLocalDay(Date.UTC(2026,8,6)), 1);
  assert.strictEqual(schedule.saturdayIndexForLocalDay(Date.UTC(2026,8,11)), 6);
});
check('no fixed weekdays starts immediately from split day one', () => {
  const out=schedule.alignPlan(rawPpl(),[],{nowMs:localNoon(2026,9,5),offsetMs:cairo});
  assert.strictEqual(out.planData.plan[0].name,'Push');
  assert.strictEqual(out.firstWorkoutDate,'2026-09-05');
  assert.strictEqual(out.scheduleStartDate,'2026-09-05');
});
check('selected Saturday starts Push today, then Pull and Legs', () => {
  const out=schedule.alignPlan(rawPpl(),[0,2,4],{nowMs:localNoon(2026,9,5),offsetMs:cairo});
  assert.strictEqual(out.planData.plan[0].name,'Push');
  assert.strictEqual(out.planData.plan[2].name,'Pull');
  assert.strictEqual(out.planData.plan[4].name,'Legs');
  assert.strictEqual(out.firstWorkoutDate,'2026-09-05');
});
check('future selected day waits, but that day receives Push', () => {
  const out=schedule.alignPlan(rawPpl(),[2,4,6],{nowMs:localNoon(2026,9,5),offsetMs:cairo});
  assert.strictEqual(out.planData.plan[0].isRest,true);
  assert.strictEqual(out.planData.plan[2].name,'Push');
  assert.strictEqual(out.planData.plan[4].name,'Pull');
  assert.strictEqual(out.planData.plan[6].name,'Legs');
  assert.strictEqual(out.firstWorkoutDate,'2026-09-07');
});
check('midweek signup rotates PPL from the next chosen weekday', () => {
  const out=schedule.alignPlan(rawPpl(),[1,3,6],{nowMs:localNoon(2026,9,10),offsetMs:cairo});
  assert.strictEqual(out.planData.plan[6].name,'Push');
  assert.strictEqual(out.planData.plan[1].name,'Pull');
  assert.strictEqual(out.planData.plan[3].name,'Legs');
  assert.strictEqual(out.firstWorkoutDate,'2026-09-11');
  assert.strictEqual(out.scheduleStartDate,'2026-09-05');
});
check('mismatched selected-day count is rejected', () => {
  assert.throws(() => schedule.alignPlan(rawPpl(),[0,2],{nowMs:localNoon(2026,9,5),offsetMs:cairo}), /preferred_days_count_mismatch/);
});

console.log(`\n${passed} passed, 0 failed`);
