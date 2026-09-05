'use strict';
// اختبارات العقل الغذائي الموحّد (مصدر واحد للقواعد + قاعدة الأكل)
const assert = require('assert');
const rules = require('../lib/nutrition-rules');
const DB = require('../lib/egyptian-food-db');

let pass = 0, fail = 0;
function t(name, fn) {
  try { fn(); pass++; console.log('  \u2713 ' + name); }
  catch (e) { fail++; console.log('  \u2717 ' + name + ' \u2014 ' + e.message); }
}
function mkFood(nameAr, cat, grams, per100) {
  const p = per100 || { cal: 100, pro: 5, carb: 10, fat: 3 };
  const k = (grams || 100) / 100;
  return { food: { id: nameAr, nameAr: nameAr, cat: cat, per100: p }, grams: grams || 100, cals: Math.round(p.cal * k), pro: p.pro * k, carb: p.carb * k, fat: p.fat * k };
}
function meal(slotKey, label, foods) { return { slotKey: slotKey, label: label, foods: foods }; }

console.log('== canonical Egyptian food DB ==');

t('الفطار فيه كل العناصر اللي اتقالت', function () {
  const want = ['فول مدمس','جبنة قريش','جبنة رومي','جبنة رودس','جبنة بيضاء','بيض مقلي','بيض مسلوق','بطاطس','عيش بلدي','عيش أسمر','عيش أبيض','رايس كيك','زبادي'];
  const have = DB.BREAKFAST.map(function (x) { return x.nameAr; });
  want.forEach(function (w) { assert.ok(have.indexOf(w) >= 0, 'missing: ' + w); });
  assert.strictEqual(DB.BREAKFAST.length, want.length);
});

t('الغدا: فراخ/لحوم/أسماك/خضار مطبوخ وشوربة/كارب', function () {
  assert.strictEqual(DB.LUNCH_PROTEIN_CHICKEN.length, 4);
  assert.strictEqual(DB.LUNCH_PROTEIN_MEAT.length, 4);
  assert.strictEqual(DB.LUNCH_FISH.length, 5);
  assert.strictEqual(DB.LUNCH_COOKED_VEG_SOUP.length, 11);
  assert.ok(DB.CARBS.some(function (x) { return x.nameAr === 'مكرونة'; }));
  assert.ok(DB.CARBS.some(function (x) { return /بني/.test(x.nameAr); }));
});

t('التونة عليها سقف 200جم', function () {
  const tuna = DB.LUNCH_FISH.find(function (x) { return x.nameAr === 'تونة'; });
  assert.strictEqual(tuna.maxGramsPerDay, 200);
  assert.strictEqual(DB.DAILY_LIMITS.tunaMaxGrams, 200);
  assert.strictEqual(DB.DAILY_LIMITS.yogurtMaxGrams, 200);
});

t('طبق السلطة = 3 عناصر وفلفل أخضر فقط', function () {
  assert.strictEqual(DB.SALAD_PLATE_SIZE, 3);
  assert.ok(DB.SALAD_ITEMS.some(function (x) { return x.nameAr === 'فلفل أخضر'; }));
  assert.ok(!DB.SALAD_ITEMS.some(function (x) { return /ملوّن/.test(x.nameAr); }));
});

t('المكمّلات: زيت/زبدة 2..10جم، زيتون 40..50جم حد 3/أسبوع، طحينة حد 3/أسبوع', function () {
  const oil = DB.COMPLEMENTS.find(function (x) { return x.id === 'oil'; });
  const butter = DB.COMPLEMENTS.find(function (x) { return x.id === 'butter'; });
  const olives = DB.COMPLEMENTS.find(function (x) { return x.id === 'olives'; });
  const tahina = DB.COMPLEMENTS.find(function (x) { return x.id === 'tahina'; });
  assert.strictEqual(oil.gramsMin, 2); assert.strictEqual(oil.gramsMax, 10);
  assert.strictEqual(butter.gramsMin, 2); assert.strictEqual(butter.gramsMax, 10);
  assert.strictEqual(olives.gramsMin, 40); assert.strictEqual(olives.gramsMax, 50); assert.strictEqual(olives.maxPerWeek, 3);
  assert.strictEqual(tahina.maxPerWeek, 3);
  // الزيت مايرتبطش بالجبنة الرومي
  assert.ok(oil.linkedTo.indexOf('gebna_romy') === -1);
  assert.ok(oil.linkedTo.indexOf('foul') >= 0);
});

t('السناك: التوليفات الثمانية بالظبط', function () {
  assert.strictEqual(DB.SNACK_COMBOS.length, 8);
  const flat = DB.SNACK_COMBOS.map(function (c) { return c.join('+'); });
  ['fruit+nuts','termes','popcorn','termes+nuts','popcorn+nuts','dark_choco+fruit','zabady+fruit','zabady+nuts']
    .forEach(function (c) { assert.ok(flat.indexOf(c) >= 0, 'missing snack: ' + c); });
});

t('قبل التمرين: قهوة سادة أساس + 1 أو 2 عنصر', function () {
  assert.strictEqual(DB.PRE_WORKOUT_BASE.nameAr, 'قهوة سادة');
  assert.strictEqual(DB.PRE_WORKOUT_MIN_ADDONS, 1);
  assert.strictEqual(DB.PRE_WORKOUT_MAX_ADDONS, 2);
  const ids = DB.PRE_WORKOUT_ADDONS.map(function (x) { return x.id; });
  ['banana','apple','dark_choco','dates','sweet_potato','pomegranate'].forEach(function (i) { assert.ok(ids.indexOf(i) >= 0, 'missing preworkout: ' + i); });
  assert.ok(DB.PRE_WORKOUT_ADDONS.find(function (x) { return x.id === 'sweet_potato'; }).seasonal);
  assert.ok(DB.PRE_WORKOUT_ADDONS.find(function (x) { return x.id === 'pomegranate'; }).seasonal);
});

t('توليفات الفطار: مسموح 2 بروتين، ممنوع 3', function () {
  assert.strictEqual(DB.BREAKFAST_MIX_MAX_PROTEINS, 2);
});

console.log('== validate() ==');

t('مفيش رز في الفطار', function () {
  const plan = { meals: [meal('breakfast', 'الفطار', [mkFood('رز أبيض', 'carb', 100)])] };
  const v = rules.validate(plan);
  assert.ok(v.some(function (x) { return x.code === 'no_rice_breakfast'; }));
});

t('خضار مطبوخ + سلطة = مخالفة', function () {
  const plan = { meals: [meal('lunch', 'الغدا', [mkFood('ملوخية', 'cooked_veg', 200), mkFood('طماطم', 'salad_veg', 50)])] };
  assert.ok(rules.validate(plan).some(function (x) { return x.code === 'cookedveg_xor_salad'; }));
});

t('سمك + خضار مطبوخ/شوربة/بطاطس = مخالفة', function () {
  const plan = { meals: [meal('lunch', 'الغدا', [mkFood('سمك بلطي مشوي', 'fish', 200), mkFood('بطاطس مطبوخة', 'cooked_veg', 150)])] };
  assert.ok(rules.validate(plan).some(function (x) { return x.code === 'no_cookedveg_soup_potato_with_fish'; }));
});

t('رز + تونة = مخالفة', function () {
  const plan = { meals: [meal('lunch', 'الغدا', [mkFood('تونة', 'fish', 150), mkFood('رز أبيض', 'carb', 100)])] };
  assert.ok(rules.validate(plan).some(function (x) { return x.code === 'no_rice_with_tuna'; }));
});

t('تونة > 200جم = مخالفة', function () {
  const plan = { meals: [meal('lunch', 'الغدا', [mkFood('تونة', 'fish', 250)])] };
  assert.ok(rules.validate(plan).some(function (x) { return x.code === 'tuna_over_limit'; }));
});

t('زبادي > 200جم = مخالفة', function () {
  const plan = { meals: [meal('breakfast', 'الفطار', [mkFood('زبادي', 'dairy', 300)])] };
  assert.ok(rules.validate(plan).some(function (x) { return x.code === 'yogurt_over_limit'; }));
});

t('وجبة > 40% من اليوم = مخالفة', function () {
  const plan = { meals: [
    meal('breakfast', 'الفطار', [mkFood('بيض مسلوق', 'egg', 100, { cal: 700, pro: 10, carb: 5, fat: 20 })]),
    meal('lunch', 'الغدا', [mkFood('صدر فراخ', 'protein_chicken', 100, { cal: 200, pro: 30, carb: 0, fat: 5 })]),
    meal('dinner', 'العشا', [mkFood('صدر فراخ', 'protein_chicken', 100, { cal: 100, pro: 30, carb: 0, fat: 5 })]),
  ] };
  assert.ok(rules.validate(plan).some(function (x) { return x.code === 'meal_share_too_high'; }));
});

t('الفطار بـ 3 بروتينات (جبنة+فول+بيض) = مخالفة', function () {
  const plan = { meals: [meal('breakfast', 'الفطار', [mkFood('جبنة بيضاء', 'cheese', 50), mkFood('فول مدمس', 'legume_cooked', 100), mkFood('بيض مسلوق', 'egg', 60)])] };
  assert.ok(rules.validate(plan).some(function (x) { return x.code === 'breakfast_too_many_proteins'; }));
});

t('الفطار بـ جبنة+فول = مسموح (مفيش مخالفة)', function () {
  const plan = { meals: [meal('breakfast', 'الفطار', [mkFood('جبنة بيضاء', 'cheese', 50), mkFood('فول مدمس', 'legume_cooked', 100)])] };
  assert.ok(!rules.validate(plan).some(function (x) { return x.code === 'breakfast_too_many_proteins'; }));
});

t('العشا فيه عنصر جديد = مخالفة', function () {
  const plan = { meals: [
    meal('breakfast', 'الفطار', [mkFood('فول مدمس', 'legume_cooked', 100)]),
    meal('lunch', 'الغدا', [mkFood('صدر فراخ', 'protein_chicken', 150)]),
    meal('dinner', 'العشا', [mkFood('سمك بلطي مشوي', 'fish', 150)]),
  ] };
  assert.ok(rules.validate(plan).some(function (x) { return x.code === 'dinner_new_item'; }));
});

console.log('== enforce() — يصحّح ويبقى نظيف ==');

t('enforce بيشيل الرز من الفطار وبعدين validate نظيف', function () {
  const plan = { meals: [meal('breakfast', 'الفطار', [mkFood('رز أبيض', 'carb', 100), mkFood('فول مدمس', 'legume_cooked', 100)])] };
  const out = rules.enforce(plan);
  assert.ok(out.fixes.some(function (x) { return x.code === 'no_rice_breakfast'; }));
  assert.ok(!rules.validate(out.plan).some(function (x) { return x.code === 'no_rice_breakfast'; }));
});

t('enforce متكرّر (idempotent): تاني مرة مايعملش تغيير', function () {
  const plan = { meals: [
    meal('lunch', 'الغدا', [mkFood('تونة', 'fish', 300), mkFood('رز أبيض', 'carb', 100)]),
  ] };
  const first = rules.enforce(plan);
  const secondFixCount = rules.enforce(first.plan).fixes.length;
  assert.strictEqual(secondFixCount, 0, 'التطبيق التاني لازم يبقى نظيف');
  assert.ok(rules.validate(first.plan).length === 0);
});

t('enforce بيقلّل التونة لـ 200جم', function () {
  const plan = { meals: [meal('lunch', 'الغدا', [mkFood('تونة', 'fish', 300)])] };
  const out = rules.enforce(plan);
  const tuna = out.plan.meals[0].foods.find(function (f) { return /تونة/.test(f.food.nameAr); });
  assert.strictEqual(tuna.grams, 200);
});

console.log('\n' + (fail === 0 ? '\u2705' : '\u274c') + ' nutrition-rules: ' + pass + ' passed, ' + fail + ' failed');
process.exit(fail === 0 ? 0 : 1);
