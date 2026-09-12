'use strict';
// [FIX-GENDER-HAMZA] عقد ترجمة النوع — يمنع رجوع الخلل اللي اتصلح:
// جسر الموبايل كان بيبعت 'انثى' بدون همزة والمحرك كله بيفحص بـ 'أنثى'،
// فقواعد الإناث الخاصة (حد 1200 سعر، IBW 45.5، منطق cut للإناث) ما كانتش
// بتتفعل لمستخدمات التطبيق. الاختبار ده بيقفل الباب على ده رجوعه.
const assert = require('assert');
const bridge = require('../lib/mobile-nutrition-bridge');
const host = require('../lib/nutrition-engine-host');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); pass++; console.log('  ✓ ' + name); }
  catch (e) { fail++; console.log('  ✗ ' + name + ' -> ' + e.message); }
}

console.log('\n[gender-translation-contract]');

const femaleMobile = { gender: 'female', age: 28, height: 165, weight: 95, goal: 'lose' };
const maleMobile   = { gender: 'male',   age: 28, height: 180, weight: 95, goal: 'lose' };

t('الجسر بيترجم female -> أنثى (بالهمزة اللي المحرك بيفحص بيها)', () => {
  const ctx = bridge.buildEngineContext(femaleMobile, {});
  assert.strictEqual(ctx.profile.gender, 'أنثى');
  assert.strictEqual(ctx.inputs['inp-gender'], 'أنثى');
});

t('الجسر بيترجم male -> ذكر', () => {
  const ctx = bridge.buildEngineContext(maleMobile, {});
  assert.strictEqual(ctx.profile.gender, 'ذكر');
});

t('الأنثى بتوصل لقواعد الإناث فعلًا — BMR أقل من الذكر بنفس المواصفات', () => {
  const base = { age: 28, height: 170, weight: 90, target: 70, activity: 1.55, goal: 'cut', selectedDiet: 'balanced', mealCount: 4, isTrainingDay: true };
  const m = host.computeTargets(Object.assign({}, base, { gender: 'ذكر' }), {});
  const f = host.computeTargets(Object.assign({}, base, { gender: 'أنثى' }), {});
  assert.ok(f.bmr < m.bmr, 'BMR الأنثى لازم يقل: ' + f.bmr + ' !< ' + m.bmr);
  assert.notDeepStrictEqual(f.macros, m.macros, 'ماكروز الأنثى المفروض تفرق عن الذكر');
});

t('سياق الجسر بيشتغل في المحرك من غير أخطاء', () => {
  const ctx = bridge.buildEngineContext(femaleMobile, {});
  const t0 = host.computeTargets(ctx.profile, ctx.inputs);
  assert.ok(Number(t0.targetCals) > 0, 'targetCals موجب');
});

console.log('[gender-translation-contract] ' + pass + ' passed, ' + fail + ' failed');
process.exit(fail === 0 ? 0 : 1);
