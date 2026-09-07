'use strict';
const assert=require('assert'),host=require('../lib/nutrition-engine-host'),rules=require('../lib/nutrition-rules'),DB=require('../lib/egyptian-food-db');
const raw=/طماطم|خيار|فلفل أخضر|جزر|خس|جرجير|بصل/;
const starch=/أرز|ارز|رز|عيش|خبز|توست|بطاطس|بطاطا|مكرونة|مكرونه/;
function names(m){return(m.foods||[]).map(f=>String(f.food&&f.food.nameAr||''));}
for(const mealCount of [2,3,4,5])for(const training of [false,true])for(let seed=0;seed<7;seed++){
 const p={gender:'male',age:30,height:181,weight:108,target:90,activity:1.375,goal:'lose',selectedDiet:'balanced',diet:'balanced',mealCount,isTrainingDay:training,preWorkoutVariant:seed,saladVariant:seed};
 const plan=host.computeMealPlan(p,{}).plan, normal=(plan.meals||[]).filter(m=>!m._autoPreWorkout),total=(plan.meals||[]).reduce((a,m)=>a+(m.foods||[]).reduce((x,f)=>x+(+f.cals||0),0),0);
 for(const m of plan.meals||[]){const ns=names(m),all=ns.join(' '),raws=ns.filter(n=>raw.test(n)),carbs=ns.filter(n=>starch.test(n));
  assert.ok(!/شوفان/.test(all),'ظهر شوفان');assert.ok(carbs.length<=1,'مصدران كارب: '+all);
  if(/breakfast|lunch|dinner/.test(String(m.slotKey||''))&&!/خضار مشكل|كوسة مطبوخة|فاصوليا خضراء|بسلة بالجزر|ملوخية|شوربة/.test(all))assert.equal(raws.length,3,'السلطة ليست 3 عناصر: '+all);
  if(m._autoPreWorkout){assert.equal(ns.filter(n=>/قهوة/.test(n)).length,1);assert.equal(ns.length,2,'قبل التمرين ليس قهوة + مصدر واحد');}
  if(/سمك|تونة|كفتة|كبدة|كبد وقوانص|قوانص/.test(all))assert.ok(!/خضار مشكل|كوسة مطبوخة|فاصوليا خضراء|بسلة بالجزر|ملوخية|شوربة/.test(all),'خضار مطبوخ مع بروتين ممنوع');
  if(/طحينة/.test(all)){const f=(m.foods||[]).find(x=>/طحينة/.test(String(x.food&&x.food.nameAr||'')));assert.ok(+f.grams>=20&&+f.grams<=50);}
  const mc=(m.foods||[]).reduce((x,f)=>x+(+f.cals||0),0);if(/breakfast|lunch|dinner/.test(String(m.slotKey||'')))assert.ok(mc/total<=(normal.length<=2?.50:.40)+.002,'سقف الوجبة');
 }
 assert.deepEqual(rules.validate(plan).filter(v=>['salad_exactly_three','oats_forbidden','preworkout_pair_required','no_cookedveg_with_banned_protein'].includes(v.code)),[]);
}
assert.equal(DB.COMPLEMENTS.find(x=>x.id==='olives').maxPerWeek,5);assert.deepEqual(DB.COMPLEMENTS.find(x=>x.id==='tahina')&&[DB.COMPLEMENTS.find(x=>x.id==='tahina').gramsMin,DB.COMPLEMENTS.find(x=>x.id==='tahina').gramsMax],[20,50]);
assert.deepEqual(DB.PRE_WORKOUT_ADDONS.find(x=>x.id==='sweet_potato').seasonMonths,[8,9,10,11,12,1]);
console.log('final-owner-rules-v2: generated matrix passed');
