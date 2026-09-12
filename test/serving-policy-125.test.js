'use strict';
const assert=require('node:assert/strict'),h=require('../lib/nutrition-engine-host'),b=require('../lib/mobile-nutrition-bridge'),policy=require('../lib/meal-serving-policy');
assert.equal(policy.effectiveMealCount(2,2200),2);assert.equal(policy.effectiveMealCount(2,2201),3);assert.equal(policy.effectiveMealCount(4,3000),4);
let checked=0;const olives={};
for(const requested of [2,3,4])for(const weight of [55,80,108])for(const week of [1,2,3])for(const day of [0,2,4,6]){
 const profile={age:30,height:180,weight,targetWeight:Math.max(50,weight-8),gender:'male',goal:'maintain',dailyActivity:'light',diet:'balanced',mealCount:requested,trainingDays:0};
 const ctx=b.buildEngineContext(profile,{});ctx.inputs['inp-week']=week;ctx.inputs.dayOfCycle=day;
 const out=h.computeMealPlan(ctx.profile,ctx.inputs),p=out.plan,meals=p.meals.filter(m=>!m._autoPreWorkout);
 assert.equal(meals.length,policy.effectiveMealCount(requested,out.targets.targetCals));
 let rods=0;
 for(const m of meals){
  assert(m.foods.length);let rice=0,salad=0;
  for(const f of m.foods){const n=String(f.food.nameAr),g=+f.grams;assert(g>0);if(/أرز|ارز|(?:^|\s)رز/.test(n))rice+=g;if(f.food.cat==='salad_veg'||/سلطة/.test(n))salad+=g;
   if(/رودس/.test(n)){assert(g>=80&&g<=150);assert.equal(n,'جبنة رودس طبيعي');rods++;}
   if(/زيتون مخلل/.test(n)){assert.notEqual(week,3);assert([week%7,(week+3)%7].includes(day));olives[week]=(olives[week]||0)+1;}
  }
  assert(rice<=400,'rice '+rice);assert(salad<=300,'salad '+salad);
 }
 assert(rods<=1);
 if(meals.length===2){const dinner=meals.find(m=>m.slotKey==='dinner');assert(dinner);assert(dinner.foods.some(f=>/فراخ|دجاج|لحم|لحمة|كفتة|كبد|قوانص|سمك|بلطي|بوري|ماكريل|سردين|تونة/.test(f.food.nameAr)),'dinner needs main protein');}
 const actual=meals.reduce((s,m)=>s+m.foods.reduce((a,f)=>a+(+f.cals||0),0),0);
 assert(Math.abs(p._macroAudit.actualCals-p.totals.cals)<=2,'audit stale');
 assert.equal(p.portionLimited,Math.abs(p._calorieGap)>100);assert(actual>0);checked++;
}
console.log('PASS: '+checked+' generated plans; boundary, counts, portions, Rouds, olive schedule, dinner, final audit');
