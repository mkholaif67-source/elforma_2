'use strict';
const host = require('./lib/nutrition-engine-host');
const bridge = require('./lib/mobile-nutrition-bridge');

function nm(f){ return String((f&&f.food&&f.food.nameAr)||(f&&f.nameAr)||'').replace(/[\u00A0\u200f\u200e\u202a-\u202e\ufeff]/g,' ').replace(/\s+/g,' ').trim(); }
function cat(f){ return String((f&&f.food&&(f.food.cat||f.food.category))||(f&&f.cat)||''); }
function grams(f){ return Number(f&&f.grams)||0; }
function isEgg(f){ return /(?<![\u0621-\u064a])\u0628\u064a\u0636(?![\u0621-\u064a])/.test(nm(f)); }
function isTuna(f){ return /\u062a\u0648\u0646\u0629|\u062a\u0648\u0646\u0647/.test(nm(f)); }
function protCat(f){ if(cat(f)!=='protein') return null; var n=nm(f);
  if(/\u0628\u064a\u0636/.test(n)) return null;
  if(/\u062a\u0648\u0646\u0629|\u062a\u0648\u0646\u0647/.test(n)) return 'tuna';
  if(/\u0633\u0645\u0643|\u0628\u0644\u0637\u064a|\u0628\u0648\u0631\u064a|\u0645\u0627\u0643\u0631\u064a\u0644|\u0645\u0643\u0631\u064a\u0644|\u0633\u0631\u062f\u064a\u0646|\u0633\u0644\u0645\u0648\u0646/.test(n)) return 'fish';
  if(/\u0641\u0631\u0627\u062e|\u062f\u062c\u0627\u062c|\u0635\u062f\u0631|\u0648\u0631\u0643|\u062c\u0646\u0627\u062d/.test(n)) return 'chicken';
  if(/\u0643\u0628\u062f|\u0643\u0628\u062f\u0629|\u0642\u0648\u0627\u0646\u0635/.test(n)) return 'liver';
  if(/\u0644\u062d\u0645|\u0628\u0642\u0631\u064a|\u0643\u0641\u062a\u0629|\u0643\u0641\u062a\u0647|\u0643\u0628\u0627\u0628|\u0628\u0641\u062a\u064a\u0643|\u0631\u064a\u0634|\u0627\u0633\u0643\u0646\u062f\u0631\u0627\u0646|\u0625\u0633\u0643\u0646\u062f\u0631\u0627\u0646/.test(n)) return 'meat';
  return 'other'; }
function isCookedVeg(f){ var n=nm(f); return /\u062e\u0636\u0627\u0631 \u0645\u0637\u0628\u0648\u062e|\u062e\u0636\u0627\u0631 \u0633\u0648\u062a\u064a\u0647|\u0633\u0648\u062a\u064a\u0647|\u0628\u0627\u0645\u064a\u0629|\u0628\u0627\u0645\u064a\u0647|\u0645\u0644\u0648\u062e\u064a\u0629|\u0645\u0644\u0648\u062e\u064a\u0647|\u0643\u0648\u0633\u0629|\u0643\u0648\u0633\u0647|\u0628\u0627\u0630\u0646\u062c\u0627\u0646|\u0633\u0628\u0627\u0646\u062e|\u0642\u0631\u0646\u0628\u064a\u0637|\u0628\u0631\u0648\u0643\u0644\u064a|\u0641\u0627\u0635\u0648\u0644\u064a\u0627 \u062e\u0636\u0631\u0627\u0621|\u0628\u0633\u0644\u0629|\u0628\u0633\u0644\u0647/.test(n); }
function isSoup(f){ var n=nm(f); return /\u0639\u062f\u0633|\u0634\u0648\u0631\u0628\u0629|\u0634\u0648\u0631\u0628\u0647/.test(n); }
function isYogurt(f){ return /\u0632\u0628\u0627\u062f\u064a/.test(nm(f)); }
function isBannedYogurt(f){ var n=nm(f); return isYogurt(f) && /\u064a\u0648\u0646\u0627\u0646\u064a|\u0644\u0627\u064a\u062a|\u0628\u0627\u0644\u0641\u0627\u0643\u0647\u0629/.test(n); }
function hasSalad(meal){ return (meal.foods||[]).some(function(f){ var n=nm(f); return /\u0633\u0644\u0637\u0629|\u0633\u0644\u0637\u0647|\u0637\u0645\u0627\u0637\u0645|\u062e\u064a\u0627\u0631|\u062e\u0633|\u062c\u0631\u062c\u064a\u0631/.test(n); }); }
function slotOf(meal){ var s=String(meal.slotKey||'')+' '+String(meal.label||'');
  if(/\u0641\u0637\u0627\u0631|\u0641\u0637\u0648\u0631|\u0625\u0641\u0637\u0627\u0631|breakfast/.test(s)) return 'breakfast';
  if(/\u063a\u062f\u0627|lunch/.test(s)) return 'lunch';
  if(/\u0639\u0634\u0627|dinner/.test(s)) return 'dinner';
  if(/\u0633\u0646\u0627\u0643|\u062a\u062d\u0644\u064a\u0629|snack/.test(s)) return 'snack';
  return String(meal.slotKey||'other'); }

function buildPlan(prof){ var ctx=bridge.buildEngineContext(prof,{}); ctx.inputs['inp-week']=1; ctx.inputs.dayOfCycle=1; var out=host.computeMealPlan(ctx.profile, ctx.inputs); return out.plan||out; }

var diets=['balanced','mediterranean','carbcycle','keto','lowcarb','carnivore'];
var profs=[];
var genders=['male','female']; var goals=['lose','maintain','gain'];
for(var i=0;i<20;i++){
  var d=diets[i%diets.length];
  profs.push({ _id:'U'+(i+1), age:22+((i*3)%40), height:158+((i*2)%30), weight:55+((i*7)%55), targetWeight:55+((i*5)%40), gender:genders[i%2], goal:goals[i%3], dailyActivity:(i%2?'moderate':'light'), diet:d, mealCount:(i%2?4:3), trainingDays:(i%3), healthConditions:[] });
}

var violations=[];
function V(u,rule,detail){ violations.push(u+' ['+rule+'] '+detail); }
var dump=[];

profs.forEach(function(p){
  var plan; try{ plan=buildPlan(p);}catch(e){ V(p._id,'CRASH',e.message); return; }
  if(plan.ownerPreError) V(p._id,'PRE_ERR',plan.ownerPreError);
  if(plan.ownerPostError) V(p._id,'POST_ERR',plan.ownerPostError);
  var meals=plan.meals||[];
  var lines=[p._id+' ('+p.diet+','+p.gender+','+p.goal+')'];
  var dayProtCats={}; var tunaTotal=0; var yogurtTotal=0;
  meals.forEach(function(m){ var slot=slotOf(m); var foods=m.foods||[];
    lines.push('  ['+slot+'] '+foods.map(function(f){return nm(f)+':'+grams(f)+'g';}).join(', '));
    foods.forEach(function(f){ var n=nm(f);
      if(/\u062d\u0645\u0635 \u0645\u0633\u0644\u0648\u0642|\u062d\u0645\u0635 \u0645\u0637\u0628\u0648\u062e/.test(n)) V(p._id,'R3',slot+' \u062d\u0645\u0635 \u0645\u0646\u0641\u0631\u062f');
      if(/\u0641\u0627\u0635\u0648\u0644\u064a\u0627 \u062d\u0645\u0631\u0627\u0621/.test(n)) V(p._id,'R11',slot+' \u0641\u0627\u0635\u0648\u0644\u064a\u0627 \u062d\u0645\u0631\u0627\u0621');
      if((slot==='breakfast'||slot==='lunch'||slot==='dinner') && /\u0628\u0637\u0627\u0637\u0633 \u0645\u0642\u0644\u064a\u0629|\u0634\u064a\u0628\u0633\u064a/.test(n)) V(p._id,'R4',slot+' '+n);
    });
    foods.forEach(function(f){ if(isBannedYogurt(f)) V(p._id,'R5-type',slot+' '+nm(f)); });
    if(foods.some(isYogurt)){
      if(foods.some(isCookedVeg)) V(p._id,'R5-veg',slot);
      if(foods.some(function(f){return protCat(f);})) V(p._id,'R5-prot',slot+' '+foods.filter(function(f){return protCat(f);}).map(nm).join('/'));
    }
    foods.forEach(function(f){ if(isYogurt(f)) yogurtTotal+=grams(f); if(isTuna(f)) tunaTotal+=grams(f); });
    var tah=foods.some(function(f){return /\u0637\u062d\u064a\u0646\u0629|\u0637\u062d\u064a\u0646\u0647/.test(nm(f));});
    var oliv=foods.some(function(f){var n=nm(f); return /\u0632\u064a\u062a\u0648\u0646/.test(n) && !/\u0632\u064a\u062a \u0632\u064a\u062a\u0648\u0646/.test(n);});
    if(tah&&oliv) V(p._id,'R9',slot);
    if(slot==='snack'){ foods.forEach(function(f){ var n=nm(f);
      if(isSoup(f)||isCookedVeg(f)||protCat(f)||isEgg(f)||/\u062c\u0628\u0646|\u0642\u0631\u064a\u0634/.test(n)||/\u0641\u0648\u0644 \u0645\u062f\u0645\u0633/.test(n)||/\u0631\u0632|\u0623\u0631\u0632|\u0645\u0643\u0631\u0648\u0646\u0629|\u0645\u0643\u0631\u0648\u0646\u0647/.test(n)||/\u0639\u064a\u0634|\u062a\u0648\u0633\u062a|\u0631\u063a\u064a\u0641/.test(n)||/\u0628\u0637\u0627\u0637\u0633|\u0628\u0637\u0627\u0637\u0627/.test(n)) V(p._id,'R10',slot+' '+n); }); }
    if(slot==='breakfast'||slot==='lunch'||slot==='dinner'){ var _fish=foods.some(function(f){var n=nm(f); return /\u0633\u0645\u0643|\u0628\u0644\u0637\u064a|\u0628\u0648\u0631\u064a|\u0645\u0627\u0643\u0631\u064a\u0644|\u0645\u0643\u0631\u064a\u0644|\u0633\u0631\u062f\u064a\u0646|\u0633\u0644\u0645\u0648\u0646|\u0628\u0644\u0627\u0645\u064a\u0637|\u0642\u0627\u0631\u0648\u0635|\u062f\u0646\u064a\u0633|\u062a\u0648\u0646\u0629|\u062a\u0648\u0646\u0647/.test(n);}); if(_fish){ foods.forEach(function(f){ var n=nm(f); if(/\u0628\u0637\u0627\u0637\u0633|\u0628\u0637\u0627\u0637\u0627/.test(n)||isCookedVeg(f)||isSoup(f)) V(p._id,'FISH_PAIR',slot+' '+n); }); } }
    var pcs={}; foods.forEach(function(f){ var pc=protCat(f); if(pc) pcs[pc]=1; });
    if(Object.keys(pcs).length>1) V(p._id,'R12',slot+' '+Object.keys(pcs).join('+'));
    Object.keys(pcs).forEach(function(k){ dayProtCats[k]=1; });
    if(foods.some(isTuna)&&foods.some(isEgg)) V(p._id,'EGG_TUNA',slot);
    if(foods.some(function(f){return protCat(f);}) && !hasSalad(m)){ foods.forEach(function(f){ var n=nm(f); if(/\u0632\u064a\u062a \u0632\u064a\u062a\u0648\u0646/.test(n)||/\u0632\u0628\u062f\u0629|\u0632\u0628\u062f\u0647|\u0633\u0645\u0646\u0629|\u0633\u0645\u0646\u0647/.test(n)) V(p._id,'R14',slot+' '+n); }); }
    if(p.diet==='balanced' && slot==='breakfast'){
      var hasGrain=foods.some(function(f){var n=nm(f); return /\u0639\u064a\u0634|\u0631\u0627\u064a\u0633 \u0643\u064a\u0643|rice cake|\u0628\u0637\u0627\u0637\u0633|\u0628\u0637\u0627\u0637\u0627|\u062a\u0648\u0633\u062a/.test(n);});
      if(!hasGrain) V(p._id,'R1-carb','\u0645\u0641\u064a\u0634 \u0643\u0627\u0631\u0628 \u062d\u0628\u0648\u0628');
      var pc=foods.filter(function(f){var n=nm(f); var c=cat(f); return c==='protein'||c==='dairy'||/\u0641\u0648\u0644 \u0645\u062f\u0645\u0633|\u0628\u064a\u0636|\u062c\u0628\u0646|\u0642\u0631\u064a\u0634/.test(n);}).length;
      if(pc<2) V(p._id,'R1-prot','\u0628\u0631\u0648\u062a\u064a\u0646<2 ('+pc+')');
    }
    if(p.diet==='balanced' && (slot==='breakfast'||slot==='lunch'||slot==='dinner')){
      if(foods.some(isSoup) && (foods.some(function(f){return cat(f)==='carb'&&!isSoup(f);})||foods.some(isCookedVeg))) V(p._id,'R3-soup',slot);
    }
  });
  if(tunaTotal>200) V(p._id,'R7',' tuna '+tunaTotal+'g');
  if(yogurtTotal>150) V(p._id,'R5-cap',' yogurt '+yogurtTotal+'g');
  if(Object.keys(dayProtCats).length>1) V(p._id,'R13','day='+Object.keys(dayProtCats).join(','));
  dump.push(lines.join('\n'));
});

console.log(dump.join('\n\n'));
console.log('\n===== VIOLATIONS ('+violations.length+') =====');
console.log(violations.length? violations.join('\n') : 'NONE - all 20 plans clean');
