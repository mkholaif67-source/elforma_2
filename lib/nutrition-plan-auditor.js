'use strict';
// Final nutrition-plan invariant gate.
// The browser engine chooses foods; this module only sizes the chosen foods so
// the plate shown in Flutter is compatible with the same calories/macros shown
// on the analysis screen. It also rejects token portions such as 20 g cooked rice.

function catalogFood(catalog, nameRx, cat) {
  return (catalog || []).find(f => (!cat || String(f.cat || f.category || '').toLowerCase() === cat) &&
    nameRx.test(String(f.nameAr || f.name || '').replace(/[\u00a0\u200e\u200f]/g, ' ')));
}

function nameOf(entry) {
  return String((entry && entry.food && (entry.food.nameAr || entry.food.nameEn)) ||
    (entry && (entry.nameAr || entry.name)) || '')
    .replace(/[\u00a0\u200e\u200f\u202a-\u202e\ufeff]/g, ' ')
    .replace(/\s+/g, ' ').trim();
}
function catOf(entry) {
  return String((entry && entry.food && (entry.food.cat || entry.food.category)) ||
    (entry && (entry.cat || entry.category)) || '').toLowerCase();
}
function baseOf(entry, key) {
  const food = entry && entry.food;
  const aliases = key === 'cal' ? ['cal', 'cals', 'calories']
    : key === 'pro' ? ['pro', 'protein']
    : key === 'carb' ? ['carb', 'carbs'] : ['fat', 'fats'];
  for (const k of aliases) {
    const n = Number(food && food[k]);
    if (Number.isFinite(n)) return n;
  }
  for (const k of aliases) {
    const n = Number(food && food.per100 && food.per100[k]);
    if (Number.isFinite(n)) return n;
  }
  const grams = Number(entry && entry.grams);
  if (grams > 0) {
    for (const k of aliases) {
      const n = Number(entry && entry[k]);
      if (Number.isFinite(n)) return n * 100 / grams;
    }
  }
  return 0;
}
function setGrams(entry, grams) {
  const name = nameOf(entry);
  const fine = /زيت|زبدة|زبده|سمن/.test(name) && !/سوداني/.test(name);
  const g = fine ? Math.round(grams) : Math.round(grams / 5) * 5;
  entry.grams = Math.max(fine ? 0 : 5, g);
  const round1 = x => Math.round(x * 10) / 10;
  entry.cals = Math.round(baseOf(entry, 'cal') * entry.grams / 100);
  entry.pro = round1(baseOf(entry, 'pro') * entry.grams / 100);
  entry.carb = round1(baseOf(entry, 'carb') * entry.grams / 100);
  entry.fat = round1(baseOf(entry, 'fat') * entry.grams / 100);
  if (entry.calories != null) entry.calories = entry.cals;
  if (entry.protein != null) entry.protein = entry.pro;
  if (entry.carbs != null) entry.carbs = entry.carb;
  return entry;
}
function isPre(meal) {
  return !!(meal && meal._autoPreWorkout) || /(^|\s)pre($|\s)|قبل التمرين/i.test(String(meal && meal.slotKey) + ' ' + String(meal && meal.label));
}
function isVeg(entry) {
  const c = catOf(entry), n = nameOf(entry);
  return /veg|vegetable/.test(c) || /سلطة|خيار|طماطم|فلفل|خس|جرجير|بصل/.test(n);
}
function isAddedFat(entry) {
  const n = nameOf(entry);
  return /زيت زيتون|زبدة|زبده|سمنة|سمنه/.test(n) && !/فول سوداني/.test(n);
}
function isRice(entry) { return /أرز|ارز|(?:^|\s)رز/.test(nameOf(entry)); }
function isTuna(entry) { return /تونة|تونه/.test(nameOf(entry)); }
function isBread(entry) { return /عيش|خبز|توست/.test(nameOf(entry)); }
function bounds(entry, meal) {
  const n = nameOf(entry), c = catOf(entry);
  if (isAddedFat(entry)) return { min: 2, max: Number(entry&&entry._addonMaxGrams)||(String(meal&&meal._dietKey||'')==='keto'?25:10), step: 1, optional: true };
  if (isPre(meal)) return { min: Math.max(5, Number(entry.grams) || 5), max: Math.max(5, Number(entry.grams) || 5), step: 5 };
  if (/أرز|رز|مكرونة|مكرونه/.test(n)) return { min: 70, max: 350, step: 5 };
  if (/بطاط/.test(n)) return { min: 100, max: 400, step: 5 };
  if (/عيش|خبز|توست/.test(n)) return { min: 50, max: 150, step: 5 };
  if (/طحينة|طحينه/.test(n)) return { min: 20, max: 50, step: 5 };
  if (/زبادي/.test(n)) return { min: 60, max: 200, step: 5 };
  if (catOf(entry) === 'egg' || /(^|\s)بيض(\s|$)/.test(n)) return { min: 100, max: 150, step: 5 };
  if (/فول/.test(n) && !/سوداني/.test(n)) return { min: 80, max: 200, step: 5 };
  if (/تونة|تونه/.test(n)) return { min: 100, max: 250, step: 5 };
  if (c === 'protein' || /فراخ|دجاج|لحمة|لحم|سمك|بلطي|بوري|سلمون|جمبري/.test(n)) return { min: 100, max: 250, step: 5 };
  if (/جبنة رومي|جبنه رومي/.test(n)) return { min: 60, max: 70, step: 5 };
  if (/جبنة رودس|جبنه رودس/.test(n)) return { min: 60, max: 200, step: 5 };
  if (c === 'dairy' || /جبن|زبادي|لبن/.test(n)) return { min: 60, max: 250, step: 5 };
  if (c === 'fruit') return { min: 100, max: 300, step: 5 };
  if (c === 'nut') return { min: 15, max: 60, step: 5 };
  if (isVeg(entry)) return { min: 40, max: 350, step: 5 };
  if (c === 'carb') return { min: 70, max: 350, step: 5 };
  return { min: 20, max: 400, step: 5 };
}
function totals(plan) {
  const out = { cals: 0, pro: 0, carb: 0, fat: 0 };
  for (const meal of plan.meals || []) {
    const mt = { cals: 0, pro: 0, carb: 0, fat: 0 };
    for (const f of meal.foods || []) {
      mt.cals += Number(f.cals != null ? f.cals : f.calories) || 0;
      mt.pro += Number(f.pro != null ? f.pro : f.protein) || 0;
      mt.carb += Number(f.carb != null ? f.carb : f.carbs) || 0;
      mt.fat += Number(f.fat) || 0;
    }
    mt.cals = Math.round(mt.cals); mt.pro = Math.round(mt.pro);
    mt.carb = Math.round(mt.carb); mt.fat = Math.round(mt.fat);
    meal.totals = Object.assign({}, meal.totals || {}, mt);
    if (meal.cals != null) meal.cals = mt.cals;
    if (meal.calories != null) meal.calories = mt.cals;
    out.cals += mt.cals; out.pro += mt.pro; out.carb += mt.carb; out.fat += mt.fat;
  }
  out.cals = Math.round(out.cals); out.pro = Math.round(out.pro);
  out.carb = Math.round(out.carb); out.fat = Math.round(out.fat);
  plan.totals = Object.assign({}, plan.totals || {}, out);
  return out;
}
function targetMacros(plan) {
  const m = plan.targetMacros || {};
  return {
    pro: Number(m.protein != null ? m.protein : m.pro) || 0,
    carb: Number(m.carbs != null ? m.carbs : m.carb) || 0,
    fat: Number(m.fat) || 0,
  };
}
function mealLimit(meal, count, targetCals) {
  if (isPre(meal) || /snack|سناك|تحلية|post|بعد التمرين/i.test(String(meal.slotKey) + ' ' + String(meal.label))) {
    return targetCals * 0.20;
  }
  return targetCals * (count <= 2 ? 0.50 : 0.40);
}
function objective(plan) {
  const t = totals(plan), m = targetMacros(plan), tc = Number(plan.targetCals) || 0;
  let score = Math.abs(t.cals - tc) / Math.max(60, tc * 0.035) * 2.2;
  if (m.pro) score += Math.abs(t.pro - m.pro) / Math.max(8, m.pro * 0.10) * 2.2;
  if (m.carb) score += Math.abs(t.carb - m.carb) / Math.max(12, m.carb * 0.10) * 1.35;
  if (m.fat) score += Math.abs(t.fat - m.fat) / Math.max(5, m.fat * 0.12) * 1.25;
  const real = (plan.meals || []).filter(x => x && !isPre(x) && (x.foods || []).length);
  for (const meal of real) {
    const over = (meal.totals && meal.totals.cals || 0) - mealLimit(meal, real.length, tc);
    if (over > 0) score += over / 20;
  }
  return score;
}
function eligibleOilMeal(meal) {
  const names = (meal.foods || []).map(nameOf).join(' ');
  return /سلطة|فول مدمس|جبن|أرز|رز|خضار مطبوخ|لوبيا|فاصوليا/.test(names);
}
function addNeededOil(plan, catalog) {
  const m = targetMacros(plan), now = totals(plan);
  if (!m.fat || now.fat >= m.fat * 0.90) return;
  let used = 0;
  for (const meal of plan.meals || []) for (const f of meal.foods || []) if (isAddedFat(f)) used += Number(f.grams) || 0;
  let remaining = Math.max(0, 20 - used);
  for (const meal of plan.meals || []) {
    if (remaining < 2 || !eligibleOilMeal(meal) || isPre(meal)) continue;
    if ((meal.foods || []).some(isAddedFat)) continue;
    const g = Math.min(10, remaining, Math.max(2, Math.round(m.fat - totals(plan).fat)));
    const food = catalogFood(catalog, /زيت زيتون|^زيت$/, 'fat');
    if (!food) continue;
    const entry = { food, grams: 0, cals: 0, pro: 0, carb: 0, fat: 0, _nutritionAuditAdded: true };
    setGrams(entry, g); meal.foods.push(entry); remaining -= g;
  }
}
function topUpExistingFats(plan) {
  const target=Number(plan.targetCals)||0, wanted=targetMacros(plan), now=totals(plan);
  if(now.cals>=target-45 || !wanted.fat || now.fat>=wanted.fat*0.95) return;
  let used=0; for(const m of plan.meals||[]) for(const f of m.foods||[]) if(isAddedFat(f)) used+=Number(f.grams)||0;
  let room=Math.max(0,20-used), need=Math.min(target-now.cals,(wanted.fat-now.fat)*9);
  for(const m of plan.meals||[]) for(const f of m.foods||[]){
    if(room<1||need<5||!isAddedFat(f)) continue;
    const b=bounds(f,m),g=Number(f.grams)||0,add=Math.min(room,b.max-g,Math.ceil(need/8.84));
    if(add>0){setGrams(f,g+add);room-=add;need-=add*8.84;}
  }
}
function ensureFatFloor(plan, wanted, catalog) {
  if(!wanted||!wanted.fat) return;
  let now=totals(plan);
  if(now.fat>=wanted.fat*0.75) return;
  const target=Number(plan.targetCals)||0;
  const meals=(plan.meals||[]).filter(m=>m&&!isPre(m)&&/مشوي|فراخ|دجاج|لحمة|لحم|سمك|بلطي|بوري/.test((m.foods||[]).map(nameOf).join(' ')))
    .sort((a,b)=>(a.totals.cals||0)-(b.totals.cals||0));
  for(const meal of meals){
    let f=(meal.foods||[]).find(x=>/طحينة|طحينه/.test(nameOf(x)));
    if(!f){
      if(now.cals+119>target+100) continue;
      const food=catalogFood(catalog, /طحينة|طحينه/, 'fat');
      if(!food) continue;
      f={food,grams:0,cals:0,pro:0,carb:0,fat:0,_nutritionAuditAdded:true};
      meal.foods.push(f); setGrams(f,20); return;
    }
    const b=bounds(f,meal),g=Number(f.grams)||0;
    if(g+5<=b.max&&now.cals+30<=target+100){setGrams(f,g+5);now=totals(plan);if(now.fat>=wanted.fat*0.75)return;}
  }
}
function addNeededTahini(plan, catalog) {
  const m = targetMacros(plan), now = totals(plan);
  if (!m.fat || now.fat >= m.fat * 0.88) return;
  const meal = (plan.meals || []).find(x => {
    if (!x || isPre(x)) return false;
    const names = (x.foods || []).map(nameOf).join(' ');
    return /مشوي|فراخ|دجاج|لحمة|لحم|سمك|بلطي|بوري/.test(names) &&
      !/خضار مطبوخ|كوسة|بسلة|ملوخية|بامية/.test(names) &&
      !(x.foods || []).some(f => /طحينة|طحينه/.test(nameOf(f)));
  });
  if (!meal) return;
  const missing = Math.max(0, m.fat - now.fat);
  const grams = Math.max(20, Math.min(40, Math.round(missing / 0.53 / 5) * 5));
  const food = catalogFood(catalog, /طحينة|طحينه/, 'fat');
  if (!food) return;
  const entry = { food, grams: 0, cals: 0, pro: 0, carb: 0, fat: 0, _nutritionAuditAdded: true };
  setGrams(entry, grams); meal.foods.push(entry);
}
function directMacroPass(plan, key, target, mode) {
  if (!(target > 0)) return;
  const value = () => Number(totals(plan)[key]) || 0;
  const wanted = mode === 'down' ? target * 1.05 : target * 0.96;
  for (let guard = 0; guard < 500; guard++) {
    const current = value();
    if ((mode === 'down' && current <= wanted) || (mode === 'up' && current >= wanted)) break;
    const candidates = [];
    for (const meal of plan.meals || []) for (const f of meal.foods || []) {
      if (isPre(meal) || isVeg(f)) continue;
      const b = bounds(f, meal), g = Number(f.grams) || 0;
      const density = baseOf(f, key);
      if (!(density > 0)) continue;
      if (mode === 'down' && g - b.step >= b.min) candidates.push({ f, next: g - b.step, density, room: g - b.min });
      if (mode === 'up' && g + b.step <= b.max) candidates.push({ f, next: g + b.step, density, room: b.max - g });
    }
    if (!candidates.length) break;
    candidates.sort((a, b) => (b.density - a.density) || (b.room - a.room));
    setGrams(candidates[0].f, candidates[0].next);
  }
}
function enforceDailyCaps(plan) {
  let oil = 0, bread = 0, yogurt = 0, tuna = 0, egg = 0;
  const oilMax=String(plan&&plan._dietKey||'')==='keto'?50:20;
  for (const meal of plan.meals || []) {
    for (const f of meal.foods || []) {
      const n = nameOf(f);
      if (isAddedFat(f)) {
        const room = Math.max(0, oilMax - oil); setGrams(f, Math.min(Number(f.grams) || 0, room)); oil += Number(f.grams) || 0;
      }
      if (/عيش|خبز|توست/.test(n)) {
        const room = Math.max(0, 200 - bread);
        if (room < 50) setGrams(f, 0);
        else setGrams(f, Math.min(Number(f.grams) || 0, room));
        bread += Number(f.grams) || 0;
      }
      if (/زبادي/.test(n)) {
        const room = Math.max(0, 200 - yogurt);
        setGrams(f, Math.min(Number(f.grams) || 0, room)); yogurt += Number(f.grams) || 0;
      }
      if (/تونة|تونه/.test(n)) {
        const room = Math.max(0, 300 - tuna);
        setGrams(f, Math.min(Number(f.grams) || 0, room)); tuna += Number(f.grams) || 0;
      }
      if (catOf(f) === 'egg' || /(^|\s)بيض(\s|$)/.test(n)) {
        const room = Math.max(0, 300 - egg);
        setGrams(f, Math.min(Number(f.grams) || 0, room)); egg += Number(f.grams) || 0;
      }
    }
    meal.foods = (meal.foods || []).filter(f => Number(f.grams) > 0);
  }
}
function removeForbiddenPairs(plan) {
  for (const meal of plan.meals || []) {
    const hasTuna = (meal.foods || []).some(isTuna);
    if (hasTuna) meal.foods = (meal.foods || []).filter(f => !isRice(f));
  }
}
function addPotato(meal, grams, catalog) {
  const food=catalogFood(catalog, /بطاط/, 'carb');
  if(!food) return null;
  const entry={food,grams:0,cals:0,pro:0,carb:0,fat:0,_nutritionAuditAdded:true};
  setGrams(entry,grams); meal.foods.push(entry); return entry;
}
function ensureCarbClosurePath(plan, catalog) {
  const target=Number(plan.targetCals)||0, gap=target-totals(plan).cals;
  if(gap<=100) return;
  const active=(plan.meals||[]).filter(m=>m&&!isPre(m)&&(m.foods||[]).length);
  if(!active.length) return;
  const candidates=active.slice().sort((a,b)=>(a.totals.cals||0)-(b.totals.cals||0));
  let dest=candidates.find(m=>!(m.foods||[]).some(isTuna))||candidates[0];
  const growable=(dest.foods||[]).some(f=>{
    const b=bounds(f,dest),g=Number(f.grams)||0;
    return !isBread(f)&&!isVeg(f)&&baseOf(f,'carb')>=15&&g+b.step<=b.max;
  });
  if(growable) return;
  let source=null;
  for(const m of active){
    if(m===dest) continue;
    source=(m.foods||[]).find(f=>!isBread(f)&&!isRice(f)&&baseOf(f,'carb')>=15);
    if(source) break;
  }
  if(source){
    const copy={food:Object.assign({},source.food||{}),grams:0,cals:0,pro:0,carb:0,fat:0,_nutritionAuditAdded:true};
    setGrams(copy,bounds(source,dest).min); dest.foods.push(copy); return;
  }
  // No reusable starch exists (common in tuna days). Seed a familiar Egyptian
  // starch in breakfast and repeat it at dinner, preserving the owner rule
  // that dinner does not introduce an item unseen earlier in the day.
  const first=active[0], last=active[active.length-1];
  if(!(first.foods||[]).some(f=>/بطاطس مسلوقة/.test(nameOf(f)))) addPotato(first,100,catalog);
  if(last!==first && !(last.foods||[]).some(f=>/بطاطس مسلوقة/.test(nameOf(f)))) addPotato(last,100,catalog);
}
function closeCalorieGap(plan) {
  const target = Number(plan.targetCals) || 0;
  for (let guard = 0; guard < 800 && totals(plan).cals < target - 45; guard++) {
    const all = (plan.meals || []).filter(m => m && !isPre(m) && (m.foods || []).length);
    const totalNow = totals(plan).cals;
    let best = null;
    const breadUsed = (plan.meals || []).reduce((s,m)=>s+(m.foods||[])
      .filter(isBread).reduce((a,f)=>a+(Number(f.grams)||0),0),0);
    for (const meal of all) {
      const tuna = (meal.foods || []).some(isTuna);
      const limit = target * (all.length <= 2 ? 0.50 : 0.415);
      if ((meal.totals && meal.totals.cals || 0) >= limit - 8) continue;
      for (const f of meal.foods || []) {
        if (isVeg(f) || isAddedFat(f) || (tuna && isRice(f)) || (isBread(f) && breadUsed >= 200)) continue;
        const b = bounds(f, meal), g = Number(f.grams) || 0;
        if (g + b.step > b.max || baseOf(f, 'carb') < 15) continue;
        const density = baseOf(f, 'carb');
        if (!best || density > best.density ||
            (density === best.density && (meal.totals.cals || 0) < (best.meal.totals.cals || 0))) {
          best = { meal, f, next: g + b.step, density };
        }
      }
    }
    if (!best) break;
    setGrams(best.f, best.next);
  }
}
function closeRemainingGap(plan) {
  const target=Number(plan.targetCals)||0,wanted=targetMacros(plan);
  for(let guard=0;guard<300&&totals(plan).cals<target-80;guard++){
    const now=totals(plan); let best=null;
    for(const meal of plan.meals||[]){
      if(isPre(meal)) continue;
      for(const f of meal.foods||[]){
        if(isVeg(f)||isAddedFat(f)||isBread(f)) continue;
        const b=bounds(f,meal),g=Number(f.grams)||0;
        if(g+b.step>b.max) continue;
        const dc=baseOf(f,'cal')*b.step/100,dp=baseOf(f,'pro')*b.step/100,
          dcarb=baseOf(f,'carb')*b.step/100,df=baseOf(f,'fat')*b.step/100;
        if(wanted.pro&&now.pro+dp>wanted.pro*1.18) continue;
        if(wanted.carb&&now.carb+dcarb>wanted.carb*1.18) continue;
        if(wanted.fat&&now.fat+df>wanted.fat*1.22) continue;
        if(!best||dc>best.dc) best={f,next:g+b.step,dc};
      }
    }
    if(!best) break;
    setGrams(best.f,best.next);
  }
}
function pruneExcessCarbEntries(plan,wanted) {
  if(!wanted||!wanted.carb) return;
  for(let guard=0;guard<8&&totals(plan).carb>wanted.carb*1.12;guard++){
    const now=totals(plan); let best=null;
    for(const meal of plan.meals||[]){
      const carbs=(meal.foods||[]).filter(f=>!isVeg(f)&&baseOf(f,'carb')>=15);
      if(carbs.length<2) continue;
      for(const f of carbs){
        if(isBread(f)) continue;
        const amount=baseOf(f,'carb')*(Number(f.grams)||0)/100,after=now.carb-amount;
        if(after<wanted.carb*0.95) continue;
        const score=Math.abs(after-wanted.carb)+(f._nutritionAuditAdded?-5:0);
        if(!best||score<best.score) best={meal,f,score};
      }
    }
    if(!best) break;
    best.meal.foods=best.meal.foods.filter(f=>f!==best.f);
  }
}
function balanceMealShares(plan) {
  const active = (plan.meals || []).filter(m => m && !isPre(m) && (m.foods || []).length);
  if (active.length < 2) return;
  for (let guard = 0; guard < 400; guard++) {
    const totalNow = totals(plan).cals;
    const shareCeiling = active.length <= 2 ? 0.50 : 0.345;
    const over = active.find(m => (m.totals.cals || 0) / totalNow > shareCeiling);
    if (!over) break;
    const under = active.slice().sort((a,b)=>(a.totals.cals||0)-(b.totals.cals||0))[0];
    if (!under || under === over) break;
    let moved = false;
    const donors = (over.foods || []).filter(f => !isVeg(f)).sort((a,b)=>baseOf(b,'cal')-baseOf(a,'cal'));
    for (const donor of donors) {
      const db = bounds(donor, over), dg = Number(donor.grams) || 0;
      if (dg - db.step < db.min) continue;
      let recipient = (under.foods || []).find(f => {
        const rb=bounds(f,under), rg=Number(f.grams)||0;
        return nameOf(f)===nameOf(donor) && rg+rb.step<=rb.max && !((under.foods||[]).some(isTuna)&&isRice(f));
      });
      if (!recipient) recipient = (under.foods || []).find(f => {
        const rb=bounds(f,under), rg=Number(f.grams)||0;
        return catOf(f)===catOf(donor) && rg+rb.step<=rb.max &&
          !isVeg(f) && !isAddedFat(f) && !((under.foods||[]).some(isTuna)&&isRice(f));
      });
      if (!recipient) continue;
      const rb=bounds(recipient,under), rg=Number(recipient.grams)||0;
      setGrams(donor,dg-db.step); setGrams(recipient,rg+rb.step); moved=true; break;
    }
    if (!moved) break;
  }
}

// Closing a calorie gap can move a meal share; redistributing that share can
// expose serving room again. Two bounded passes settle both constraints without
// introducing an open-ended chain of post-processors.
function settleDistribution(plan, catalog) {
  for (let pass = 0; pass < 2; pass++) {
    enforceDailyCaps(plan);
    ensureCarbClosurePath(plan, catalog);
    closeCalorieGap(plan);
    balanceMealShares(plan);
  }
  removeForbiddenPairs(plan);
  enforceDailyCaps(plan);
  balanceMealShares(plan);
}

function reconcile(plan, catalog) {
  if (!plan || !Array.isArray(plan.meals) || !(Number(plan.targetCals) > 0)) return null;
  catalog = Array.isArray(catalog) ? catalog : [];
  removeForbiddenPairs(plan);
  for (const meal of plan.meals) {
    meal.foods = Array.isArray(meal.foods) ? meal.foods : [];
    for (const f of meal.foods) {
      const b = bounds(f, meal); let g = Number(f.grams) || 0;
      if (isAddedFat(f) && g < b.min) continue;
      g = Math.max(b.min, Math.min(b.max, g)); setGrams(f, g);
    }
    meal.foods = meal.foods.filter(f => !isAddedFat(f) || Number(f.grams) >= 2);
  }
  enforceDailyCaps(plan);
  const wanted = targetMacros(plan);
  // Break the old failure mode first: excess lean protein cannot be used as a
  // generic calorie filler. Then refill the released budget with the macro it
  // actually belongs to.
  directMacroPass(plan, 'pro', wanted.pro, 'down');
  directMacroPass(plan, 'carb', wanted.carb, 'down');
  addNeededOil(plan, catalog);
  addNeededTahini(plan, catalog);
  directMacroPass(plan, 'carb', wanted.carb, 'up');
  directMacroPass(plan, 'pro', wanted.pro, 'up');

  let score = objective(plan);
  for (let pass = 0; pass < 700; pass++) {
    let best = null;
    for (const meal of plan.meals) {
      for (const f of meal.foods || []) {
        if (isVeg(f) || isPre(meal)) continue;
        const b = bounds(f, meal), current = Number(f.grams) || 0;
        for (const dir of [-1, 1]) {
          const next = current + dir * b.step;
          if (next < b.min || next > b.max) continue;
          setGrams(f, next); const candidate = objective(plan); setGrams(f, current);
          if (candidate + 0.0001 < score && (!best || candidate < best.score)) best = { f, next, score: candidate };
        }
      }
    }
    if (!best) break;
    setGrams(best.f, best.next); score = best.score;
  }
  settleDistribution(plan, catalog);
  // The calorie closer may add a repeated starch after meal-count merging.
  // Re-apply the protein ceiling once more, then replace the released calories
  // with that starch. This keeps 2-meal plans from meeting calories by carrying
  // unnecessarily high egg/cheese protein.
  directMacroPass(plan, 'pro', wanted.pro, 'down');
  pruneExcessCarbEntries(plan,wanted);
  directMacroPass(plan, 'carb', wanted.carb, 'down');
  topUpExistingFats(plan);
  ensureFatFloor(plan, wanted, catalog);
  if((Number(plan.targetCals)||0)-totals(plan).cals>100){
    if(!wanted.carb||totals(plan).carb<wanted.carb*0.95){
      ensureCarbClosurePath(plan, catalog);
      closeCalorieGap(plan);
    }
    closeRemainingGap(plan);
  }
  balanceMealShares(plan);
  enforceDailyCaps(plan);
  const actual = totals(plan), cals = Number(plan.targetCals);
  const pct = (a, b) => b > 0 ? Math.round((a - b) / b * 1000) / 10 : 0;
  const audit = {
    targetCals: Math.round(cals), actualCals: actual.cals, calorieGap: Math.round(cals - actual.cals),
    targetMacros: wanted, actualMacros: { pro: actual.pro, carb: actual.carb, fat: actual.fat },
    driftPct: { protein: pct(actual.pro, wanted.pro), carbs: pct(actual.carb, wanted.carb), fat: pct(actual.fat, wanted.fat) },
  };
  audit.passed = Math.abs(audit.calorieGap) <= 100 &&
    (!wanted.pro || Math.abs(audit.driftPct.protein) <= 20) &&
    (!wanted.carb || Math.abs(audit.driftPct.carbs) <= 18) &&
    (!wanted.fat || Math.abs(audit.driftPct.fat) <= 25);
  plan._calorieGap = audit.calorieGap;
  plan._macroAudit = audit;
  return audit;
}

module.exports = { reconcile, totals, bounds, nameOf };
