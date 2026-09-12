'use strict';
const nutrition = require('../lib/nutrition-engine-host');
const profiles = [
  { name: 'balanced 4 meals (lose)', p: { gender:'male', age:30, height:178, weight:82, target:75, activity:1.55, goal:'lose', selectedDiet:'balanced', mealCount:4 } },
  { name: 'balanced 3 meals (lose,F)', p: { gender:'female', age:26, height:165, weight:70, target:62, activity:1.375, goal:'lose', selectedDiet:'balanced', mealCount:3 } },
  { name: 'balanced 2 meals (lose)', p: { gender:'male', age:34, height:176, weight:88, target:80, activity:1.375, goal:'lose', selectedDiet:'balanced', mealCount:2 } },
  { name: 'muscle 5 meals GYM day', p: { gender:'male', age:28, height:175, weight:78, target:80, activity:1.725, goal:'muscle', selectedDiet:'balanced', mealCount:5, isTrainingDay:true } },
  { name: 'mediterranean 4 (F)', p: { gender:'female', age:40, height:168, weight:75, target:68, activity:1.55, goal:'lose', selectedDiet:'mediterranean', mealCount:4 } },
];
const eggGrams={}, cheeseGrams={}, oilButter=[];
let worstOver=0;
profiles.forEach(function(row){
  let res; try { res = nutrition.computeMealPlan(row.p, {}); } catch(e){ console.log('\n### '+row.name+' CRASH: '+e.message); return; }
  const meals=(res.plan&&res.plan.meals)||[];
  const day=meals.reduce(function(s,m){return s+(Number(m.totals&&m.totals.cals)||0);},0)||1;
  const real=meals.filter(function(m){return !m._autoPreWorkout;}).length;
  const cap=real<=2?50:40;
  console.log('\n### '+row.name+' | \u0648\u062c\u0628\u0627\u062a='+meals.length+' \u0625\u062c\u0645\u0627\u0644\u064a='+Math.round(day)+' kcal (\u0633\u0642\u0641='+cap+'%)');
  meals.forEach(function(m){
    const mc=Number(m.totals&&m.totals.cals)||0; const pct=Math.round(mc/day*100);
    const over=(!m._autoPreWorkout && pct>cap);
    if(over && (pct-cap)>worstOver) worstOver=pct-cap;
    console.log('  \u2022 ['+pct+'%] '+(m.label||m.slotKey)+' ('+Math.round(mc)+' kcal)'+(over?'  <<< \u0641\u0648\u0642 \u0627\u0644\u0633\u0642\u0641!':''));
    (m.foods||[]).forEach(function(f){
      const nm=String((f.food&&f.food.nameAr)||f.nameAr||''); const g=Number(f.grams)||0;
      console.log('       - '+nm+' : '+g+'g');
      if(/\u0628\u064a\u0636/.test(nm)&&!/\u0628\u064a\u0636\u0627\u0621/.test(nm)) eggGrams[g]=(eggGrams[g]||0)+1;
      if(/\u062c\u0628\u0646\u0629/.test(nm)) cheeseGrams[g]=(cheeseGrams[g]||0)+1;
      if(/\u0632\u064a\u062a\s|\u0632\u0628\u062f\u0629|\u0633\u0645\u0646\u0629/.test(nm)) oilButter.push(nm.trim()+'='+g+'g');
    });
  });
});
console.log('\n========== \u062e\u0644\u0627\u0635\u0629 ==========');
console.log('\u0623\u0642\u0635\u0649 \u062a\u062c\u0627\u0648\u0632 \u0644\u0644\u0633\u0642\u0641: '+worstOver+' \u0646\u0642\u0637\u0629 \u0645\u0626\u0648\u064a\u0629 (0 = \u0645\u0641\u064a\u0634 \u062a\u062c\u0627\u0648\u0632)');
console.log('\u062c\u0631\u0627\u0645\u0627\u062a \u0627\u0644\u0628\u064a\u0636: '+JSON.stringify(eggGrams));
console.log('\u062c\u0631\u0627\u0645\u0627\u062a \u0627\u0644\u062c\u0628\u0646\u0629: '+JSON.stringify(cheeseGrams));
console.log('\u0632\u064a\u062a/\u0632\u0628\u062f\u0629: '+JSON.stringify(oilButter));
