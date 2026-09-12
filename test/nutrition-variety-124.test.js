'use strict';
const assert=require('node:assert/strict'), host=require('../lib/nutrition-engine-host'),rules=require('../lib/nutrition-rules');
const energies=new Set(), fish=new Set(), cooked=new Set();let yogurtDays=0,chicken=0,kofta=0,plans=0;
for(let day=0;day<21;day++){
 const p={gender:'male',age:30,height:181,weight:108,target:90,activity:1.375,goal:'lose',selectedDiet:'balanced',diet:'balanced',mealCount:day%3+3,isTrainingDay:true,dayOfCycle:day%7,week:Math.floor(day/7)+1};
 const plan=host.computeMealPlan(p,{}).plan;assert(plan?.meals?.length);plans++;
 const pre=plan.meals.find(m=>m.slotKey==='pre');assert(pre);assert.equal(pre.foods.length,2);const energy=pre.foods.find(f=>!/قهوة/.test(f.food.nameAr));energies.add(energy.food.nameAr);
 const foods=plan.meals.flatMap(m=>m.foods);const ys=foods.filter(f=>/زبادي/.test(f.food.nameAr));if(ys.length)yogurtDays++;assert(ys.reduce((a,f)=>a+f.grams,0)<=200.01);
 const names=foods.map(f=>f.food.nameAr).join(' ');assert(!/عدس.*بجب/.test(names));
 if(/صدر فراخ/.test(names))chicken++;if(/كفتة فراخ/.test(names))kofta++;
 for(const f of foods){if(/بلطي|بوري|ماكريل/.test(f.food.nameAr))fish.add(f.food.nameAr);if(f.food.cat==='cooked_veg')cooked.add(f.food.nameAr);}
 const violations=rules.validate(plan).filter(v=>['lentil_starch_conflict','brown_lentil_auto_excluded','no_cookedveg_with_banned_protein','preworkout_pair_required'].includes(v.code));assert.deepEqual(violations,[]);
 const sum=foods.reduce((a,f)=>a+f.cals,0);assert(sum>=plan.targetCals-101&&sum<=plan.targetCals+51,`calories day ${day}: ${sum} / ${plan.targetCals}`);
}
console.log(JSON.stringify({plans,energies:[...energies],fish:[...fish],cooked:[...cooked],yogurtDays,chicken,kofta}));
assert(energies.size>=4,'pre-workout rotation stuck');assert([...energies].some(n=>/موز/.test(n)));assert([...energies].some(n=>/دارك/.test(n)));
assert([...fish].some(n=>/بوري/.test(n)));assert([...fish].some(n=>/ماكريل/.test(n)));assert([...fish].some(n=>/بلطي/.test(n)));
assert(yogurtDays>0,'yogurt suppressed');assert(chicken>kofta,'chicken breast should be preferred');
// Name-based lentil rules also apply when old catalog classifies them as carb.
function food(name,cat='carb'){return {food:{id:name,nameAr:name,cat,cal:116,pro:9,carb:20,fat:.4},grams:100,cals:116,pro:9,carb:20,fat:.4};}
for(const protein of ['سمك بلطي','تونة','كفتة','كبدة إسكندراني','كبد وقوانص فراخ']){
 const plan={meals:[{slotKey:'lunch',foods:[food(protein,'protein'),food('عدس أصفر مطبوخ')]}]};rules.enforce(plan);assert(!plan.meals[0].foods.some(f=>/عدس/.test(f.food.nameAr)));
}
for(const starch of ['أرز أبيض','عيش بلدي','مكرونة مطبوخة']){
 const plan={meals:[{slotKey:'lunch',foods:[food(starch),food('شوربة عدس')]}]};rules.enforce(plan);assert(!plan.meals[0].foods.some(f=>/عدس/.test(f.food.nameAr)));
}
console.log('Nutrition variety and lentil conflicts: PASS');
