'use strict';
const assert = require('node:assert/strict');
const rules = require('../lib/nutrition-rules');
const food = (nameAr, cat = 'protein') => ({food:{nameAr,cat,cal:100,pro:10,carb:5,fat:3},grams:100,cals:100,pro:10,carb:5,fat:3});
const soups = ['شوربة مرقة لحمة','شوربة مرقة دجاج','شوربه مرقه فراخ','شوربة عدس'];
const cases = [
  ['لحم مسلوق','protein_meat',[true,false,false,true]],
  ['لحم مشوي','protein',[true,false,false,true]],
  ['صدر فراخ مسلوق','protein_chicken',[false,true,true,true]],
  ['ورك دجاج','protein',[false,true,true,true]],
  ['صدر فراخ مشوي','protein',[false,false,false,false]],
  ['فراخ مشوية','protein_chicken',[false,false,false,false]],
  ['دجاج مشوى','protein',[false,false,false,false]],
  ['بيض مسلوق','egg',[false,false,false,true]],
  ['جبنة قريش','cheese',[false,false,false,true]],
  ['سمك بلطي','fish',[false,false,false,true]],
];
let checks=0;
for (const [name,cat,allowed] of cases) {
  soups.forEach((soup,index)=>{
    // Legacy catalogue labels broth as a carb; it still must obey the rule.
    const entry=food(soup,index===0?'carb':'soup');
    const foods=[food(name,cat),food('ارز بسمتي','carb'),entry];
    assert.equal(rules.soupAllowedWithFoods(entry,foods),allowed[index],`${name}: ${soup}`);
    const plan={meals:[{slotKey:'lunch',foods}],targetCals:2000};
    if (!allowed[index]) {
      assert(rules.validate(plan).some(v=>v.code==='soup_protein_pairing'));
      rules.enforce(plan);
      assert(!plan.meals[0].foods.includes(entry));
      assert(!rules.validate(plan).some(v=>v.code==='soup_protein_pairing'));
    } else if (index < 3 && /لحم|فراخ|دجاج/.test(name)) {
      rules.enforce(plan);
      assert(plan.meals[0].foods.includes(entry),'matching optional soup remains allowed');
    }
    checks++;
  });
}
for (const soup of soups.slice(0,3)) {
  const entry=food(soup,'soup');
  assert.equal(rules.soupAllowedWithFoods(entry,[entry,food('ارز بسمتي','carb')]),false,'broth is not its own matching protein');
}
for(const name of ['لحم مسلوق','صدر فراخ مسلوق']) {
  const plan={meals:[{slotKey:'lunch',foods:[food(name),food('ارز بسمتي','carb')]}],targetCals:2000};
  rules.enforce(plan);
  assert(!plan.meals[0].foods.some(rules._pred.isSoup),'soup stays optional');
}
console.log(`Soup pairing: ${checks} combinations, standalone broth rejection and optional soup passed`);
