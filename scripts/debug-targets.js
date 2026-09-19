'use strict';
const n=require('../lib/nutrition-engine-host');
const cases=[
  ['3 meals F',{gender:'female',age:26,height:165,weight:70,target:62,activity:1.375,goal:'lose',selectedDiet:'balanced',mealCount:3}],
  ['2 meals M',{gender:'male',age:34,height:176,weight:88,target:80,activity:1.375,goal:'lose',selectedDiet:'balanced',mealCount:2}],
  ['5 GYM',{gender:'male',age:28,height:175,weight:78,target:80,activity:1.725,goal:'muscle',selectedDiet:'balanced',mealCount:5,isTrainingDay:true}],
];
cases.forEach(function(c){
  const res=n.computeMealPlan(c[1],{});
  const day=(res.plan.meals||[]).reduce((s,m)=>s+((m.foods||[]).reduce((a,f)=>a+(Number(f.cals!=null?f.cals:f.calories)||0),0)),0);
  console.log('\n=== '+c[0]+' ===');
  console.log('res.targets=',JSON.stringify(res.targets));
  console.log('plan.targetCals=',res.plan.targetCals,' plan.targetMacros=',JSON.stringify(res.plan.targetMacros));
  console.log('actual day total=',Math.round(day));
  console.log('healthPruned=',res.healthPruned,' pantrySize=',res.pantrySize);
});
