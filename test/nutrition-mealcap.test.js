'use strict';
// [ROOT-CAUSE TESTS] سقف نسبة الوجبة + مفيش وجبة فاضية + تنوع الكميات.
const assert = require('assert');
const n = require('../lib/nutrition-engine-host');

let pass = 0, fail = 0;
function t(name, fn){ try { fn(); pass++; console.log('  ok  - ' + name); } catch(e){ fail++; console.log('  FAIL- ' + name + ' :: ' + e.message); } }
function mealCals(m){ return (m.foods||[]).reduce(function(s,f){ return s + (Number(f.cals!=null?f.cals:f.calories)||0); }, 0); }
function realMeals(p){ return (p.meals||[]).filter(function(m){ return !m._autoPreWorkout; }); }

const cases = [
  { name: '4 meals lose', p: { gender:'male', age:30, height:178, weight:82, target:75, activity:1.55, goal:'lose', selectedDiet:'balanced', mealCount:4 } },
  { name: '3 meals lose F', p: { gender:'female', age:26, height:165, weight:70, target:62, activity:1.375, goal:'lose', selectedDiet:'balanced', mealCount:3 } },
  { name: '2 meals lose', p: { gender:'male', age:34, height:176, weight:88, target:80, activity:1.375, goal:'lose', selectedDiet:'balanced', mealCount:2 } },
  { name: '5 meals GYM', p: { gender:'male', age:28, height:175, weight:78, target:80, activity:1.725, goal:'muscle', selectedDiet:'balanced', mealCount:5, isTrainingDay:true } },
  { name: 'mediterranean 4 F', p: { gender:'female', age:40, height:168, weight:75, target:68, activity:1.55, goal:'lose', selectedDiet:'mediterranean', mealCount:4 } },
];

console.log('\n[nutrition-mealcap]');
cases.forEach(function(c){
  const res = n.computeMealPlan(c.p, {});
  const plan = res.plan;
  const real = realMeals(plan);
  const day = real.reduce(function(s,m){ return s + mealCals(m); }, 0);
  const cap = real.length <= 2 ? 0.50 : 0.40;

  t(c.name + ' : مفيش وجبة فوق السقف', function(){
    real.forEach(function(m){
      const pct = mealCals(m) / day;
      // هامش 2.5% لأن التقريب لـ 5ج + حماية أقل 20ج وبروتين واحد ممكن يخليوا 50%→~52% في يوم الوجبتين.
      assert.ok(pct <= cap + 0.025, (m.label||m.slotKey) + ' = ' + Math.round(pct*100) + '% > ' + Math.round(cap*100) + '%');
    });
  });

  t(c.name + ' : مفيش وجبة فاضية (0 kcal)', function(){
    (plan.meals||[]).forEach(function(m){
      if (m._autoPreWorkout) return;
      const fs = (m.foods||[]);
      assert.ok(fs.length > 0, (m.label||m.slotKey) + ' مفيهاش أكل');
      assert.ok(mealCals(m) > 0, (m.label||m.slotKey) + ' = 0 kcal');
    });
  });

  t(c.name + ' : اليوم مايزيدش عن الهدف (لا أكتر)', function(){
    const target = Number(plan.targetCals) || day;
    assert.ok(day <= target * 1.08, 'إجمالي=' + Math.round(day) + ' > هدف=' + Math.round(target));
  });

  // ملاحظة معلوماتية (مش فشل): أهداف التضخيم العالية صعب توصلها بالحدود الواقعية.
  (function(){
    const target = Number(plan.targetCals) || day;
    const pctT = Math.round(day / target * 100);
    if (pctT < 85) console.log('  note- ' + c.name + ' : اليوم ' + Math.round(day) + '/' + Math.round(target) + ' (' + pctT + '% من الهدف)');
  })();
});

t('تنوع الكميات: البيض مش ثابت 150 دايماً', function(){
  const gramsSeen = {};
  cases.forEach(function(c){
    const plan = n.computeMealPlan(c.p, {}).plan;
    (plan.meals||[]).forEach(function(m){
      (m.foods||[]).forEach(function(f){
        const nm = String((f.food&&f.food.nameAr)||f.nameAr||'');
        if (/بيض/.test(nm) && !/بيضاء/.test(nm)) gramsSeen[Number(f.grams)||0] = true;
      });
    });
  });
  const distinct = Object.keys(gramsSeen);
  assert.ok(distinct.length >= 2, 'جرامات البيض كلها = ' + distinct.join(','));
});

console.log('\n[nutrition-mealcap] pass=' + pass + ' fail=' + fail);
if (fail > 0) process.exit(1);
