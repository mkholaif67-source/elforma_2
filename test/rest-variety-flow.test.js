'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');
const host = require('../lib/nutrition-engine-host');
const bridge = require('../lib/mobile-nutrition-bridge');

let pass = 0;
function check(name, fn) {
  fn(); pass++; console.log('  ✓ ' + name);
}

console.log('[rest-day UI contract]');
const workout = fs.readFileSync(path.join(__dirname, '../mobile/lib/screens/workout_screen.dart'), 'utf8');
const restStart = workout.indexOf('Widget _restDayHero(');
const restEnd = workout.indexOf('/// [OWNER-RULE] تبديل الجدول', restStart);
assert(restStart > -1 && restEnd > restStart);
const rest = workout.slice(restStart, restEnd);
check('rest day hides metrics', () => assert(workout.includes('if (!restToday)')));
check('rest day hides plan switching', () => assert(workout.includes('others.isNotEmpty && !restToday')));
check('a new plan no longer turns a rest day into a workout preview', () => {
  assert(!workout.includes('new-user exception: plan created today/yesterday'));
  assert(workout.includes("'isPreview': false"));
});
check('rest page has concise recovery focus only', () => {
  assert(rest.includes('حركة خفيفة'));
  assert(rest.includes('مية وأكل كفاية'));
  assert(rest.includes('نوم هادئ'));
  assert(!rest.includes('كيف احساسك'));
  assert(!rest.includes('الراحة مش كسل'));
});
check('next workout is hidden behind a small explicit button', () => {
  assert(rest.includes('عرض القادم من الجدول'));
  assert(rest.includes('_showRestPreview'));
  assert(rest.includes('next-workout-preview'));
});

console.log('\n[seven-day food variety contract]');
const profile = {
  age:31,height:178,weight:86,targetWeight:78,gender:'male',goal:'lose',
  dailyActivity:'moderate',diet:'balanced',mealCount:3,trainingDays:0,
  healthConditions:[]
};
function dayPlan(day, p = profile) {
  const ctx = bridge.buildEngineContext(p, {});
  ctx.inputs['inp-week'] = 1;
  ctx.inputs.dayOfCycle = day;
  const plan = host.computeMealPlan(ctx.profile, ctx.inputs).plan;
  return plan.meals.map(m => ({
    slot: m.slotKey,
    foods: (m.foods || []).map(f => (f.food && (f.food.id || f.food.nameAr)) || f.nameAr || '?')
  }));
}
function fp(day, p) { return JSON.stringify(dayPlan(day, p)); }
const week = Array.from({length:7}, (_, day) => fp(day));
check('all seven cycle days differ for the same user', () => assert.strictEqual(new Set(week).size, 7));
check('no adjacent day repeats', () => {
  for (let i=1;i<week.length;i++) assert.notStrictEqual(week[i], week[i-1]);
});
check('breakfast rotates through at least three compositions', () => {
  const values = Array.from({length:7}, (_,d) => JSON.stringify(dayPlan(d)[0].foods));
  assert(new Set(values).size >= 3);
});
check('main meals rotate through at least four compositions', () => {
  const values = [];
  for (let d=0;d<7;d++) for (const m of dayPlan(d)) if (m.slot === 'lunch') values.push(JSON.stringify(m.foods));
  assert(new Set(values).size >= 4);
});
check('a different user gets a different weekly fingerprint', () => {
  const other = {...profile, age:26, gender:'female', height:164, weight:68, targetWeight:60};
  const otherWeek = Array.from({length:7}, (_, day) => fp(day, other));
  assert.notDeepStrictEqual(otherWeek, week);
});

console.log(`\n${pass} passed, 0 failed`);
