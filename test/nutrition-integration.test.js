'use strict';
// اختبار تكامل: المحرك الحقيقي لازم يطلّع خطة بتعدّي قواعد العقل الموحّد.
const assert = require('assert');
const nutrition = require('../lib/nutrition-engine-host');
const rules = require('../lib/nutrition-rules');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); pass++; console.log('  \u2713 ' + name); }
  catch (e) { fail++; console.log('  \u2717 ' + name + ' \u2014 ' + e.message); }
}

const profiles = [
  { name: 'balanced 4 meals', p: { gender: 'male', age: 30, height: 178, weight: 82, target: 75, activity: 1.55, goal: 'lose', selectedDiet: 'balanced', mealCount: 4 } },
  { name: 'balanced 3 meals', p: { gender: 'female', age: 26, height: 165, weight: 70, target: 62, activity: 1.375, goal: 'lose', selectedDiet: 'balanced', mealCount: 3 } },
  { name: 'lowcarb 4 meals', p: { gender: 'male', age: 35, height: 180, weight: 90, target: 82, activity: 1.55, goal: 'lose', selectedDiet: 'lowcarb', mealCount: 4 } },
  { name: 'training day (pre-workout)', p: { gender: 'male', age: 28, height: 175, weight: 78, target: 78, activity: 1.725, goal: 'muscle', selectedDiet: 'balanced', mealCount: 5, isTrainingDay: true } },
  { name: 'mediterranean 4 meals', p: { gender: 'female', age: 40, height: 168, weight: 75, target: 68, activity: 1.55, goal: 'lose', selectedDiet: 'mediterranean', mealCount: 4 } },
];

console.log('== تكامل المحرك مع العقل الموحّد ==');

profiles.forEach(function (row) {
  t('الخطة (' + row.name + ') بتعدّي كل قواعد الأكل', function () {
    const res = nutrition.computeMealPlan(row.p, {});
    assert.ok(res && res.plan && Array.isArray(res.plan.meals) && res.plan.meals.length > 0, 'مفيش خطة');
    // إثبات الربط: المحرك شغّل العقل الموحّد
    assert.ok(Array.isArray(res.plan._ruleFixes), '_ruleFixes لازم تكون موجودة (دليل إن العقل اتنفّذ)');
    const v = rules.validate(res.plan);
    assert.strictEqual(v.length, 0, 'مخالفات: ' + JSON.stringify(v.map(function (x) { return x.code + '@' + x.meal; })));
  });
});

t('يوم التمرين: فيه وجبة قبل التمرين أساسها قهوة سادة', function () {
  const res = nutrition.computeMealPlan({ gender: 'male', age: 28, height: 175, weight: 78, target: 78, activity: 1.725, goal: 'muscle', selectedDiet: 'balanced', mealCount: 5, isTrainingDay: true }, {});
  const pre = res.plan.meals.find(function (m) { return String(m.slotKey || '') === 'pre' || m._autoPreWorkout || /قبل التمرين/.test(String(m.label || '')); });
  assert.ok(pre, 'مفيش وجبة قبل التمرين في يوم التمرين');
  const names = (pre.foods || []).map(function (f) { return String((f.food && f.food.nameAr) || ''); });
  assert.ok(names.some(function (n) { return /قهوة/.test(n); }), 'القهوة السادة أساس مفقود: ' + JSON.stringify(names));
});

console.log('\n' + (fail === 0 ? '\u2705' : '\u274c') + ' nutrition-integration: ' + pass + ' passed, ' + fail + ' failed');
process.exit(fail === 0 ? 0 : 1);
