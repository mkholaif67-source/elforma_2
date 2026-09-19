'use strict';
// [تحقق] وجبة ما قبل التمرين لازم تظهر لأي متدرب في يوم تمرين،
// وماتظهرش في يوم الراحة. المصدر الوحيد: profile.isTrainingDay -> _efInjectPreWorkout.
const assert = require('assert');
const host = require('../lib/nutrition-engine-host');

function baseProfile(extra) {
  return Object.assign({
    gender: '\u0630\u0643\u0631',
    age: 28,
    height: 178,
    weight: 82,
    target: 78,
    activity: 1.55,
    goal: 'cut',
    gainStyle: 'lean',
    selectedDiet: 'balanced',
    mealCount: 4,
    healthConditions: [],
    expectedWeeklyLoss: 0.6,
    sleepHours: 7,
  }, extra || {});
}

function hasPreWorkout(plan) {
  if (!plan || !Array.isArray(plan.meals)) return false;
  return plan.meals.some(function (m) {
    return m && (m._autoPreWorkout === true || String(m.slotKey || '') === 'pre' ||
      String(m.label || '').indexOf('\u0642\u0628\u0644 \u0627\u0644\u062a\u0645\u0631\u064a\u0646') > -1);
  });
}

let passed = 0, failed = 0;
function check(name, cond) {
  if (cond) { passed++; console.log('  \u2713 ' + name); }
  else { failed++; console.log('  \u2717 FAIL: ' + name); }
}

// 1) يوم تمرين -> لازم تكون فيه وجبة قبل التمرين
const trainDay = host.computeMealPlan(baseProfile({ isTrainingDay: true }), {});
check('يوم تمرين: فيه وجبة قبل التمرين', hasPreWorkout(trainDay.plan));

// 2) يوم راحة -> مفيش وجبة قبل التمرين
const restDay = host.computeMealPlan(baseProfile({ isTrainingDay: false }), {});
check('يوم راحة: مفيش وجبة قبل التمرين', !hasPreWorkout(restDay.plan));

// 3) أدوات أقل (وجبتين) + يوم تمرين -> برضو لازم تظهر
const train2 = host.computeMealPlan(baseProfile({ isTrainingDay: true, mealCount: 2 }), {});
check('وجبتين + يوم تمرين: فيه وجبة قبل التمرين', hasPreWorkout(train2.plan));

console.log('\n' + passed + ' passed, ' + failed + ' failed');
if (failed) process.exit(1);
