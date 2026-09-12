'use strict';
// Current owner composition rules. No calorie equations are changed here.
const food=e=>e&&e.food||e||{};
const name=e=>String(food(e).nameAr||food(e).name||'').replace(/[\u064B-\u0652\u0670\u0640]/g,'').replace(/[أإآ]/g,'ا').replace(/\s+/g,' ').trim();
const cat=e=>String(food(e).cat||'');
const key=e=>name(e)||String(food(e).id||''); // same ingredient may have legacy/catalogue IDs
const items=m=>Array.isArray(m.foods)?m.foods:[];
const slot=m=>String(m.slotKey||m.slot||'');
const yogurt=e=>/زبادي|يوغرت/.test(name(e));
const fruit=e=>cat(e)==='fruit';
const egg=e=>cat(e)==='egg'||/(^|\s)بيض(?:\s|$)/.test(name(e));
const cheese=e=>/جبن|لبنه/.test(name(e));
const foul=e=>/فول/.test(name(e))&&!/سوداني/.test(name(e));
const soup=e=>cat(e)==='soup'||/شورب|مرق/.test(name(e));
const cooked=e=>!foul(e)&&!soup(e)&&(/^(cooked_veg|vegetable_cooked)$/.test(cat(e))||/ملوخيه|ملوخية|كوسه.*مطبوخ|كوسة.*مطبوخ|بسله|بسلة|فاصوليا.*مطبوخ|لوبيا.*مطبوخ|خضار.*مطبوخ|سبانخ.*مطبوخ|باذنجان.*(?:مشوي|مطبوخ)|بروكلي.*(?:مطبوخ|مسلوق)|باميه|بامية/.test(name(e)));
const salad=e=>!cooked(e)&&!soup(e)&&(cat(e)==='salad_veg'||/سلطه|سلطة|طماطم|خيار|فلفل اخضر|خس|جرجير|جزر|كابوتش/.test(name(e)));
const starch=e=>!foul(e)&&/ارز|(?:^| )رز|عيش|خبز|توست|مكرون|بطاطس/.test(name(e));
const rice=e=>/ارز|(?:^| )رز/.test(name(e));
const fish=e=>/سمك|بلطي|بوري|ماكريل|مكريل|سردين|تونه|تونة/.test(name(e));
const molokhia=e=>/ملوخيه|ملوخية/.test(name(e));
const main=m=>/^(breakfast|lunch|dinner)$/.test(slot(m))&&!m._autoPreWorkout;
const snack=m=>/snack/.test(slot(m))||/سناك|تحلية/.test(String(m.label||''));
function snackAllowed(e){
 const n=name(e),c=cat(e);
 if(egg(e)||cheese(e)||foul(e)||soup(e)||cooked(e)||salad(e)||/عيش|خبز|توست|ارز|(?:^|\s)رز|مكرون|تونه|تونة|سمك|فراخ|دجاج|لحم|كبد|عدس|حمص|ترمس|فاصوليا|لوبيا/.test(n))return false;
 if(/^(protein|fish|chicken|meat|beef|legume|legume_cooked|plant_protein)$/.test(c))return false;
 // Existing permitted snack groups: fruit, nuts, yogurt, popcorn, dark chocolate.
 return yogurt(e)||fruit(e)||/^(nut|nuts)$/.test(c)||/فشار|سوداني|مكسرات|شوكولات.*(?:دارك|داكن)/.test(n);
}
function lightDinner(m){const f=items(m);return slot(m)==='dinner'&&f.some(yogurt)&&f.some(fruit)&&f.every(e=>yogurt(e)||fruit(e));}
function setGrams(e,g){const f=food(e),p=f.per100||f;e.grams=g;e.cals=Math.round(Number(p.cal||0)*g/100);for(const k of ['pro','carb','fat'])e[k]=Math.round(Number(p[k]||0)*g)/100;}
function normalizeTwoMeals(plan){const m=(plan.meals||[]).filter(main);if(m.length===2){plan._twoMealMainDinner=true;const dinner=m.find(x=>slot(x)==='dinner');if(dinner&&!m.some(x=>slot(x)==='lunch')){dinner.slotKey='lunch';dinner.label='الغداء';if('slot' in dinner)dinner.slot='lunch';}}}
function enforce(plan){
 if(!plan||!Array.isArray(plan.meals))return plan;
 normalizeTwoMeals(plan);
 let dayVeg=0;
 const seen=new Set(),earlier=new Map();
 for(const m of plan.meals){
  m.foods=items(m).filter(e=>Number(e.grams)>0);
  if(snack(m))m.foods=m.foods.filter(snackAllowed);
  if(m.foods.some(e=>egg(e)||cheese(e)||foul(e)||yogurt(e)))m.foods=m.foods.filter(e=>!cooked(e)&&!soup(e));
  if(m.foods.some(soup))m.foods=m.foods.filter(e=>!cooked(e));
  if(m.foods.some(molokhia))m.foods=m.foods.filter(e=>!cooked(e)||molokhia(e));
  if(m.foods.some(cooked))m.foods=m.foods.filter(e=>!salad(e));
  if(slot(m)==='dinner'&&!plan._twoMealMainDinner){
   const hadStarch=m.foods.find(starch),hadSalad=m.foods.some(salad);
   const hasPair=m.foods.some(yogurt)&&m.foods.some(fruit);
   if(hasPair&&m.foods.some(e=>(yogurt(e)||fruit(e))&&!seen.has(key(e)))){
    m.foods=m.foods.filter(e=>yogurt(e)||fruit(e));
    // One yogurt + one fruit; don't turn the exception into a mixed dinner.
    const y=m.foods.find(yogurt),f=m.foods.find(fruit);m.foods=[y,f];
   }else if(!lightDinner(m)){
    m.foods=m.foods.filter(e=>seen.has(key(e)));
    const previous=[...earlier.values()];
    // Use an earlier starch rather than deleting it and leaving a protein-only dinner.
    const balanced=['balanced','mediterranean','carbcycle',''].includes(String(plan._dietKey||''));
    const needsStarch=hadStarch||(balanced&&m.foods.some(e=>/بيض|فول|جبن|قريش|لحم|فراخ|دجاج|سمك|تونه|تونة|كبد|قوانص/.test(name(e))));
    if(needsStarch&&!m.foods.some(starch)){
     const labels=m.foods.map(name).join(' '),hasTuna=/تونه|تونة/.test(labels),redMeat=/لحم|لحمه/.test(labels)&&!/كفت|كبد/.test(labels);
     const candidate=previous.slice().reverse().find(e=>starch(e)&&
      (!m.foods.some(fish)||!/مكرون/.test(name(e)))&&(!hasTuna||!rice(e))&&(!redMeat||!/عيش|خبز|توست/.test(name(e))));
     if(candidate){const e=JSON.parse(JSON.stringify(candidate));const per=Number((food(e).per100||food(e)).cal)||1;
      const cap=rice(e)||/مكرون/.test(name(e))?400:/بطاطس/.test(name(e))?300:180;
      setGrams(e,Math.min(cap,Math.max(rice(e)?70:50,Math.round(Number(hadStarch&&hadStarch.cals||candidate.cals||100)/per*20)*5)));m.foods.push(e);}
    }
    // Complete the salad ONLY with vegetables already used earlier in the day.
    if(hadSalad&&!m.foods.some(cooked)){
     const selected=m.foods.filter(salad),used=new Set(selected.map(key));
     for(const e of previous.filter(salad)){if(selected.length>=3)break;if(!used.has(key(e))){selected.push(JSON.parse(JSON.stringify(e)));used.add(key(e));}}
     if(selected.length>=3){const chosen=selected.slice(0,3);chosen.forEach((e,i)=>setGrams(e,[70,60,50][i]));m.foods=m.foods.filter(e=>!salad(e)).concat(chosen);}
    }
   }
  }
  let mealVeg=0;
  m.foods=m.foods.filter(e=>{
   if(!cooked(e))return true;
   const room=Math.min(200-mealVeg,350-dayVeg);
   if(room<100)return false;
   const g=Math.min(room,Math.max(100,Math.min(200,Number(e.grams)||100)));
   setGrams(e,g);mealVeg+=g;dayVeg+=g;return true;
  });
  for(const e of m.foods){if(/(?:ارز|رز) بسمتي/.test(name(e)))e.food=Object.assign({},food(e),{nameAr:'ارز بسمتي'});seen.add(key(e));earlier.set(key(e),e);}
  m.totals={cals:0,pro:0,carb:0,fat:0};for(const e of m.foods)for(const k of Object.keys(m.totals))m.totals[k]+=Number(e[k])||0;
 }
 return plan;
}
function validate(plan){
 const out=[],seen=new Set();let total=0;const mains=(plan.meals||[]).filter(main);
 for(const m of plan.meals||[]){const f=items(m),add=(code,msg)=>out.push({code,meal:m.label||slot(m),msg});
  if(snack(m)&&f.some(e=>!snackAllowed(e)))add('snack_forbidden_food','عنصر غير مسموح في السناك');
  if(f.some(e=>egg(e)||cheese(e)||foul(e)||yogurt(e))&&f.some(e=>cooked(e)||soup(e)))add('cooked_with_breakfast_food','خضار مطبوخ أو شوربة مع أحد عناصر الفطار');
  if((f.some(cooked)&&f.some(e=>soup(e)||salad(e)))||(f.some(molokhia)&&f.some(e=>cooked(e)&&!molokhia(e))))add('cooked_pair_conflict','خضار مطبوخ مع سلطة أو شوربة');
  const veg=f.filter(cooked),g=veg.reduce((s,e)=>s+Number(e.grams||0),0);total+=g;
  if(veg.some(e=>e.grams<100||e.grams>200)||g>200)add('cooked_meal_portion','الخضار المطبوخ 100–200 جم في الوجبة');
  if(slot(m)==='dinner'&&mains.length>2&&!lightDinner(m)&&f.some(e=>!seen.has(key(e))))add('dinner_new_item','العشاء لا يضيف صنفا جديدا لليوم');
  for(const e of f)seen.add(key(e));
 }
 if(total>350)out.push({code:'cooked_day_portion',meal:'day',msg:'الخضار المطبوخ يتجاوز 350 جم في اليوم'});
 return out;
}
function favoriteAllowed(slotKey,e){
 if(slotKey==='snack')return snackAllowed(e);
 if(slotKey==='pre')return /قهوه|قهوة|موز|تفاح|تمر|بطاطا|شوكولات.*(?:دارك|داكن)/.test(name(e));
 if(slotKey==='breakfast')return !soup(e)&&!cooked(e)&&!/ارز|(?:^|\s)رز|مكرون|تونه|تونة|سمك|فراخ|دجاج|لحم|كبد/.test(name(e));
 return true;
}
module.exports={enforce,validate,normalizeTwoMeals,lightDinner,snackAllowed,favoriteAllowed,isCookedVeg:cooked,isSoup:soup};
