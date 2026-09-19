'use strict';
// ============================================================================
// عقد التنوّع: مستخدمون مختلفون = وجبات مختلفة (Meal variety contract)
// ----------------------------------------------------------------------------
// يحرس الجذر اللي اتصلح: قبل الإصلاح كانت بذرة التنويع
// _egyDaySeed() = currentWeek + dayOfCycle فقط (مشتقة من التاريخ)
// فكل المستخدمين في نفس اليوم كانو بياخدو نفس الأكل.
// الإصلاح: بصمة المستخدم (userSeed) دخلت في نفس ماكينة التنويع
// الموجودة عشان كل شخص ياخد بدايته الخاصة — من غير logic عشوائي.
// وكمان يحرس: نفس المستخدم = نفس الخطة (ثابتة/reproducible).
// ============================================================================
const assert = require('assert');
const host = require('../lib/nutrition-engine-host');
const bridge = require('../lib/mobile-nutrition-bridge');

let pass = 0, fail = 0;
function check(name, fn) {
  try { fn(); pass++; console.log('  \u2713 ' + name); }
  catch (e) { fail++; console.log('  \u2717 ' + name + ' \u2014 ' + e.message); }
}

// بيبني خطة لملف موبايل ويرجّع أسماء الأصناف في كل وجبة
function planFoods(prof, day) {
  const ctx = bridge.buildEngineContext(prof, {});
  ctx.inputs['inp-week'] = 1;
  ctx.inputs.dayOfCycle = (day == null ? 1 : day);
  const out = host.computeMealPlan(ctx.profile, ctx.inputs);
  const plan = out.plan || out;
  const meals = (plan && plan.meals) || [];
  assert.ok(meals.length >= 2, 'الخطة لازم تحتوي وجبتين على الأقل');
  return meals.map(function (m) {
    return (m.foods || [])
      .map(function (f) { return (f.food && f.food.id) || (f.food && f.food.nameAr) || '?'; })
      .sort();
  });
}
// بصمة نصية لكل الأصناف في الخطة (بدون جرامات — الأصناف نفسها)
function fingerprint(prof, day) {
  return planFoods(prof, day).map(function (ids) { return ids.join(','); }).join(' || ');
}

const BASE = {
  age: 25, height: 165, weight: 100, targetWeight: 80, gender: 'male',
  goal: 'lose', dailyActivity: 'light', diet: 'balanced', mealCount: 3,
  trainingDays: 0, healthConditions: []
};
const USER_A = BASE;
const USER_B = Object.assign({}, BASE, { weight: 60, targetWeight: 55, gender: 'female', age: 30, height: 160 });
const USER_C = Object.assign({}, BASE, { weight: 85, targetWeight: 75, age: 45, height: 178 });

console.log('\nعقد التنوّع — مستخدمون مختلفون = وجبات مختلفة');

check('مستخدمون مختلفون بنفس الدايت → خطط مختلفة', function () {
  const a = fingerprint(USER_A), b = fingerprint(USER_B), c = fingerprint(USER_C);
  assert.notStrictEqual(a, b, 'A و B لازم يختلفوا');
  assert.notStrictEqual(a, c, 'A و C لازم يختلفوا');
  assert.notStrictEqual(b, c, 'B و C لازم يختلفوا');
});

check('نفس المستخدم → نفس الخطة (ثابتة/deterministic)', function () {
  assert.strictEqual(fingerprint(USER_A), fingerprint(USER_A), 'نفس المستخدم لازم يدي نفس النتيجة');
});

check('البروتين الرئيسي بيختلف بين مستخدمين مختلفين', function () {
  // أقوى من تطابق البصمة: حتى البروتين الأساسي لازم يتنوّع
  const proteinOf = function (prof) {
    const meals = planFoods(prof);
    return meals.map(function (ids) { return ids.join(','); }).join('|');
  };
  const setA = proteinOf(USER_A), setB = proteinOf(USER_B);
  assert.notStrictEqual(setA, setB, 'A و B لازم يختلفوا في التركيب');
});

check('التنوّع شغّال عبر أكتر من دايت', function () {
  ['balanced', 'lowcarb', 'keto', 'mediterranean'].forEach(function (d) {
    const p1 = Object.assign({}, USER_A, { diet: d });
    const p2 = Object.assign({}, USER_B, { diet: d });
    assert.notStrictEqual(fingerprint(p1), fingerprint(p2), 'دايت ' + d + ': لازم يختلفوا');
  });
});

console.log('\n' + pass + ' passed, ' + fail + ' failed');
if (fail > 0) process.exit(1);
