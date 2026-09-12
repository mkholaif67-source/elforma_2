'use strict';
const assert=require('node:assert/strict');
const engine=require('../lib/workout-plan-finisher');
let checked=0,profiles=0;
for(const gender of ['male','female'])for(const equip of ['gym','home'])for(const days of [2,3,4,5,6])for(const time of [45,90]){
 const p={gender,equip,days,time,exp:'advanced',age:30,height:181,weight:108,goal:'cut',daily:'light',sleep:'ok',stress:'mid',injuries:[],weak:[]};
 const out=engine.computeStablePlan(p).out;profiles++;
 for(const plan of out.plans||[])for(const day of plan.plan||[]){
  const ex=day.exercises||[];if(day.isRest||!ex.length)continue;
  const min=gender==='female'?5:6;
  assert(ex.length>=min&&ex.length<=8,`${gender}/${equip}/${days}/${time}/${plan.key}/${day.name}: ${ex.length}`);
  assert.equal(new Set(ex.map(e=>e.n)).size,ex.length,'no duplicate exercise within day');
  checked++;
 }
}
assert(checked>0);console.log(`advanced-minimum-122: ${profiles} profiles / ${checked} training days passed`);
