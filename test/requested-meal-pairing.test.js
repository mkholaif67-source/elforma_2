'use strict';
const assert=require('assert');
const host=require('../lib/nutrition-engine-host');
const bridge=require('../lib/mobile-nutrition-bridge');
const db=require('../lib/egyptian-food-db');
const profile={age:30,height:181,weight:108,targetWeight:85,gender:'male',goal:'lose',dailyActivity:'light',diet:'balanced',mealCount:4,trainingDays:0,healthConditions:[]};
let cooked=0,yogurt=0;
for(let day=1;day<=14;day++){
  const ctx=bridge.buildEngineContext(profile,{});ctx.inputs['inp-week']=day<=7?1:2;ctx.inputs.dayOfCycle=(day-1)%7+1;
  const plan=host.computeMealPlan(ctx.profile,ctx.inputs).plan;
  let cookedToday=false,yogurtToday=false;
  for(const meal of plan.meals||[]){
    const foods=meal.foods||[], names=foods.map(f=>String(f.food&&f.food.nameAr||'')), all=names.join(' ');
    cookedToday ||= /خضار مشكل مطبوخ|كوسة مطبوخة|شوربة/.test(all); yogurtToday ||= /زبادي طبيعي/.test(all);
    for(const f of foods){const n=String(f.food&&f.food.nameAr||'');if(/زيت زيتون|زبدة/.test(n)){assert.strictEqual(f._isAddon,true,'دهن مضاف ظهر مستقل');assert.ok(+f.grams>=2&&+f.grams<=+(f._addonMaxGrams||10));}}
    if(/لحم|لحمة/.test(all)&&!/كفتة|كبد/.test(all))assert.doesNotMatch(all,/عيش|خبز|توست/);
    if(/سمك|بلطي|بوري|ماكريل|سردين/.test(all))assert.doesNotMatch(all,/مكرونة|مكرونه/);
    if(/تونة|تونه/.test(all))assert.doesNotMatch(all,/أرز|ارز|رز/);
    if(/جبنة رومي/.test(all))assert.ok(!/زيت زيتون/.test(all),'زيت مع الجبنة الرومي');
    if(/lunch|dinner/.test(String(meal.slotKey||''))){
      assert.match(all,/فراخ|لحم|لحمة|كفتة|كبد|قوانص|سمك|تونة|تونه|بيض|جبن|قريش|فول/,'وجبة رئيسية بلا بروتين');
      assert.match(all,/أرز|ارز|رز|عيش|مكرونة|مكرونه|بطاطس|شوفان/,'وجبة رئيسية بلا كارب');
      assert.match(all,/طماطم|خيار|فلفل|خس|جرجير|خضار مشكل مطبوخ|كوسة مطبوخة|شوربة/,'وجبة رئيسية بلا خضار');
    }
  }
  cooked+=cookedToday?1:0;yogurt+=yogurtToday?1:0;
}
assert.ok(cooked>=2,'الخضار المطبوخ أو الشوربة لم يظهر بانتظام');
assert.ok(yogurt>=2,'الزبادي الطبيعي مهمش');
const liver=db.LUNCH_PROTEIN_MEAT.find(f=>f.id==='kebda_eskandarani');assert.equal(liver.nameAr,'كبدة إسكندراني');assert.equal(liver.per100.cal,191);
console.log(`requested-meal-pairing passed: cooked=${cooked}, yogurt=${yogurt}`);
