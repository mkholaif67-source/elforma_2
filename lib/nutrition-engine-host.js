'use strict';
// ============================================================
//  Nutrition Engine Host (server-side)
//  Runs the SAME browser diet-engine files unchanged inside a
//  Node vm sandbox with a minimal DOM/localStorage shim, so the
//  premium plan-generation logic can execute on the server and
//  never ship to the client. Single source of truth = the same
//  files under app/diet/js that the browser loads.
// ============================================================
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const DIR = path.join(__dirname, '..', 'app', 'diet', 'js');
// Compute-relevant engine files in browser load order.
// Excluded: 11_steps_ui / 20_dashboard_bridge / 21_data_integrity — pure UI/persistence layers not needed to compute a plan.
const FILES = [
  '00_core_bootstrap.js','01_food_intelligence.js','02_meal_rules_and_constraints.js',
  '03_scoring_and_validation.js','04_food_database.js','05_engine_state.js',
  '06_food_filter_and_search.js','07_day_planner.js','08_macro_optimizer.js',
  '09_smart_meal_logic.js','10_weekly_strategy.js','11_steps_ui.js','12_nutrition_calc_engine.js',
  '13_recommendation_results_export.js','15_diet_info.js','16_subsystems.js',
  '17_smart_meal_pool.js','18_root_fix_v40.js','19_engine_facade.js',
  // 21 repairs FOOD_MAP references and rule objects (resolveArray /
  // fixRuleObject). The website loads it; this host used to skip it, so the
  // app was planning meals against unrepaired rules. 20_dashboard_bridge.js
  // stays out on purpose: it is browser-only persistence (localStorage +
  // injecting a dashboard button into document.body) and changes no food.
  '21_data_integrity_v42.js',
  '22_egyptian_meal_intelligence.js','23_egy_affordability_v53.js','25_owner_rules_post.js'
];

let currentInputs = {};

function makeStub(){
  const f = function(){ return makeStub(); };
  return new Proxy(f, {
    get: function(t,p){ if(p===Symbol.iterator) return function*(){}; if(p==='length') return 0; return makeStub(); },
    set: function(){ return true; },
    apply: function(){ return makeStub(); },
    construct: function(){ return makeStub(); }
  });
}
function makeEl(value){
  const t = { value:value, innerHTML:'', textContent:'', value_:value, className:'', style:{}, dataset:{},
    classList:{ add:function(){}, remove:function(){}, toggle:function(){}, contains:function(){return false;} },
    children:[], childNodes:[], options:[] };
  const methods = { appendChild:1, removeChild:1, setAttribute:1, getAttribute:1, hasAttribute:1,
    addEventListener:1, removeEventListener:1, insertAdjacentHTML:1, remove:1, closest:1,
    querySelector:1, querySelectorAll:1, focus:1, click:1, scrollIntoView:1, cloneNode:1, replaceChildren:1 };
  return new Proxy(t, {
    get: function(o,p){ if(p in o) return o[p]; if(methods[p]) return function(){ return makeStub(); }; return makeStub(); },
    set: function(o,p,v){ o[p]=v; return true; }
  });
}

function buildContext(){
  // Build the context with NO request inputs in scope, so the DE snapshot
  // captured below reflects pristine engine defaults and never the first
  // caller's data.
  const _savedInputs = currentInputs;
  currentInputs = {};
  const _ls = new Map();
  const localStorage = {
    getItem:function(k){ return _ls.has(k)?_ls.get(k):null; },
    setItem:function(k,v){ _ls.set(k,String(v)); },
    removeItem:function(k){ _ls.delete(k); },
    clear:function(){ _ls.clear(); },
    key:function(i){ return Array.from(_ls.keys())[i]||null; }
  };
  Object.defineProperty(localStorage,'length',{ get:function(){ return _ls.size; } });
  const sandbox = {
    console:{ log:function(){}, warn:function(){}, error:function(){}, info:function(){}, debug:function(){}, group:function(){}, groupCollapsed:function(){}, groupEnd:function(){}, table:function(){}, trace:function(){}, count:function(){}, countReset:function(){}, dir:function(){}, dirxml:function(){}, assert:function(){}, time:function(){}, timeEnd:function(){}, timeLog:function(){} },
    document:{
      getElementById:function(id){ return Object.prototype.hasOwnProperty.call(currentInputs,id) ? makeEl(String(currentInputs[id])) : makeEl(undefined); },
      querySelector:function(){ return makeEl(undefined); },
      querySelectorAll:function(){ return []; },
      getElementsByClassName:function(){ return []; },
      getElementsByTagName:function(){ return []; },
      createElement:function(){ return makeEl(undefined); },
      createElementNS:function(){ return makeEl(undefined); },
      createTextNode:function(){ return makeEl(undefined); },
      addEventListener:function(){}, removeEventListener:function(){},
      body:makeEl(undefined), head:makeEl(undefined), documentElement:makeEl(undefined),
      readyState:'complete', cookie:''
    },
    localStorage: localStorage,
    requestIdleCallback:function(){ return 0; }, cancelIdleCallback:function(){},
    requestAnimationFrame:function(){ return 0; }, cancelAnimationFrame:function(){},
    setTimeout:function(){ return 0; }, clearTimeout:function(){},
    setInterval:function(){ return 0; }, clearInterval:function(){},
    navigator:{ userAgent:'node', language:'ar' },
    location:{ href:'', search:'', pathname:'/', hash:'', origin:'' },
    history:{ pushState:function(){}, replaceState:function(){} },
    matchMedia:function(){ return { matches:false, addListener:function(){}, removeListener:function(){}, addEventListener:function(){}, removeEventListener:function(){} }; },
    getComputedStyle:function(){ return {}; },
    alert:function(){}, confirm:function(){ return false; }, prompt:function(){ return null; },
    performance:{ now:function(){ return Date.now(); } }
  };
  vm.createContext(sandbox);
  sandbox.window = sandbox; sandbox.self = sandbox; sandbox.globalThis = sandbox; sandbox.top = sandbox;
  let code = '';
  for (let i=0;i<FILES.length;i++){
    // Capture the REAL template-first meal builder (defined in module 13 +
    // v50 Egyptian templates in module 17) BEFORE the v41 facade (module 19)
    // overwrites the global `buildSmartMealPlan` with its DOM-oriented scatter
    // builder. The scatter builder ignored the Egyptian pairing templates
    // (fool+egg breakfast, tahini only with grills, peanut-butter only with
    // toast, olive-oil beside cheese) and produced unclamped portions. We keep
    // a handle to the original so the host can plan meals THROUGH the templates.
    if (FILES[i] === '19_engine_facade.js') {
      code += '\n;globalThis.__EF_TEMPLATE_BSMP = (typeof buildSmartMealPlan === "function") ? buildSmartMealPlan : null;\n';
    }
    code += '\n;/* ===== ' + FILES[i] + ' ===== */\n' + fs.readFileSync(path.join(DIR, FILES[i]),'utf8') + '\n';
  }
  code += '\n;globalThis.__EF_FOOD_CATALOG = (typeof FOOD_DB !== "undefined" ? FOOD_DB : FOOD_DB_RAW).map(function(f){ return {' +
    'id:f.id,nameAr:f.nameAr,nameEn:f.nameEn,cat:f.cat,cal:f.cal,pro:f.pro,carb:f.carb,fat:f.fat,unit:f.unit,' +
    'mealTypes:f.mealTypes||[],allowedDiets:f.allowedDiets||[],avoidHealth:f.avoidHealth||[],healthyScore:f.healthyScore||5,processedLevel:f.processedLevel||"unknown"}; });\n';
  // ── The pantry bridge ────────────────────────────────────────────────
  // 05_engine_state.js declares `const DE = {...}` at the TOP LEVEL of the
  // bundle script. Top-level const/let are lexical, NOT properties of the vm
  // global object, so `sandbox.DE` is undefined and any attempt to set
  // `sandbox.DE.availableFoods` from the host silently does nothing. That is
  // precisely why the app's pantry never reached the engine. These two
  // accessors are compiled INSIDE the same script, so they close over the real
  // DE and are the only correct way in.
  code += '\n;globalThis.__EF_SET_AVAILABLE = function(ids){ try { if (typeof DE !== "undefined" && DE) { DE.availableFoods = ids.slice(); return DE.availableFoods.length; } } catch(e){} return -1; };\n' +
    'globalThis.__EF_GET_AVAILABLE = function(){ try { if (typeof DE !== "undefined" && DE && Array.isArray(DE.availableFoods)) return DE.availableFoods.length; } catch(e){} return -1; };\n';
  // [EGY-v70] بذرة اليوم/الأسبوع — DE لكسيكال فمابنوصلهاش من الهوست إلا بستر جوّا الحزمة (زي __EF_SET_AVAILABLE).
  code += '\n;globalThis.__EF_SET_DAYSEED = function(week, day){ try { if (typeof DE !== "undefined" && DE) { if (typeof week === "number" && week > 0) DE.currentWeek = week; DE.dayOfCycle = ((Number(day)%7)+7)%7; return true; } } catch(e){} return false; };\n';
  // [FIX-VARIETY] بصمة المستخدم — تزاحة ثابتة لدورات التنويع عشان مستخدمين مختلفين = وجبات مختلفة.
  code += '\n;globalThis.__EF_SET_USERSEED = function(seed){ try { if (typeof DE !== "undefined" && DE) { DE.userSeed = ((Number(seed)%997)+997)%997; return true; } } catch(e){} return false; };\n';
  // ── Request-isolation snapshot (see resetEngineState) ────────────
  // The engine keeps ALL request state in a single top-level `const DE`.
  // The compiled context is cached and reused across requests, so any field
  // one caller leaves in DE bleeds into the NEXT caller (proven: a healthy
  // user inherited a previous user's thyroid flag + mesocycle week). DE is
  // lexical and unreachable from the host, so we snapshot its pristine
  // defaults INSIDE the bundle and expose a reset the host runs before every
  // compute. JSON round-trip is safe: DE holds only data (verified).
  code += '\n;globalThis.__EF_DE_SNAPSHOT=(function(){try{return (typeof DE!=="undefined"&&DE)?JSON.parse(JSON.stringify(DE)):null;}catch(e){return null;}})();globalThis.__EF_RESET_DE=function(){try{if(typeof DE==="undefined"||!DE||!globalThis.__EF_DE_SNAPSHOT)return false;var snap=globalThis.__EF_DE_SNAPSHOT;Object.keys(DE).forEach(function(k){if(!Object.prototype.hasOwnProperty.call(snap,k)){try{delete DE[k];}catch(_e){DE[k]=undefined;}}});var fresh=JSON.parse(JSON.stringify(snap));Object.keys(fresh).forEach(function(k){DE[k]=fresh[k];});return true;}catch(e){return false;}};\n';
  const script = new vm.Script(code, { filename:'diet-engine-bundle.js' });
  try { script.runInContext(sandbox, { timeout: 20000 }); }
  finally { currentInputs = _savedInputs; }
  return sandbox;
}

let _ctx = null;
function ctx(){ if(!_ctx) _ctx = buildContext(); return _ctx; }

// ── Sprint 13: NaN guard ────────────────────────────────────────────────
// The diet engine reads its inputs through document.getElementById(...) ids
// (inp-weight, inp-bf, inp-steps ...). When an id is missing the shim returns
// an empty element, the maths silently degrades to NaN, and the engine STILL
// returns an object -- so the app used to build meals around a non-existent
// target. Nothing may leave this host without being a finite, sane number.
// ── Sprint 15: physiological plausibility guard ────────────────────────
// Proven by probe: an empty or half-filled profile did NOT fail. The engine
// returned bmr=5, tdee=7, protein=0 g -- and because the calorie floor lifts
// the total to 1400, the old calorie-only guard waved it through and the app
// happily rendered a three-meal plan with ZERO protein. For a nutrition app
// that is not a bug, it is a hazard. A body that cannot exist must never
// receive a plan; we refuse loudly instead of guessing.
var HUMAN = {
  age:    { min: 7,   max: 80,  label: 'age' },
  height: { min: 100, max: 250, label: 'height' },
  weight: { min: 25,  max: 350, label: 'weight' }
};
function assertProfile(profile, where){
  var p = profile || {};
  Object.keys(HUMAN).forEach(function (key) {
    var spec = HUMAN[key];
    var n = Number(p[key]);
    if (!Number.isFinite(n) || n <= 0) {
      throw new Error('engine_missing_' + spec.label + ':' + where);
    }
    if (n < spec.min || n > spec.max) {
      throw new Error('engine_implausible_' + spec.label + ':' + where + ':' + n);
    }
  });
  var target = Number(p.target);
  if (Number.isFinite(target) && target > 0 &&
      (target < HUMAN.weight.min || target > HUMAN.weight.max)) {
    throw new Error('engine_implausible_target:' + where + ':' + target);
  }
  return p;
}

function assertTargets(r, where){
  if (!r || typeof r !== 'object') {
    throw new Error('engine_no_result:' + where);
  }
  const cals = Number(r.targetCals);
  if (!Number.isFinite(cals) || cals <= 0) {
    throw new Error('engine_bad_target_cals:' + where + ':' + String(r.targetCals));
  }
  // A human plan below 800 or above 8000 kcal means the inputs never arrived.
  if (cals < 800 || cals > 8000) {
    throw new Error('engine_target_out_of_range:' + where + ':' + cals);
  }
  const m = r.macros || {};
  const p = Number(m.protein), cb = Number(m.carbs), f = Number(m.fat);
  if (![p, cb, f].every(Number.isFinite)) {
    throw new Error('engine_bad_macros:' + where + ':' + JSON.stringify(m));
  }
  if (p <= 0 && cb <= 0 && f <= 0) {
    throw new Error('engine_empty_macros:' + where);
  }
  // Sprint 15: protein is the one macro that is never optional. A plan that
  // prescribes 0 g of protein means the inputs never reached Mifflin-St Jeor.
  if (p <= 0) {
    throw new Error('engine_zero_protein:' + where);
  }
  // A resting metabolism under 800 kcal is not survivable for an adult, so it
  // can only mean height/weight/age arrived empty.
  var bmrVal = Number(r.bmr);
  if (Number.isFinite(bmrVal) && bmrVal > 0 && bmrVal < 800) {
    throw new Error('engine_implausible_bmr:' + where + ':' + Math.round(bmrVal));
  }
  var tdeeVal = Number(r.tdee);
  if (Number.isFinite(tdeeVal) && tdeeVal > 0 && tdeeVal < 900) {
    throw new Error('engine_implausible_tdee:' + where + ':' + Math.round(tdeeVal));
  }
  // The calorie floor must never silently outrun the maths: if the target had
  // to be lifted to double the computed expenditure, the expenditure is fiction.
  if (Number.isFinite(tdeeVal) && tdeeVal > 0 && cals > tdeeVal * 2) {
    throw new Error('engine_target_exceeds_tdee:' + where + ':' + cals + '>' + Math.round(tdeeVal));
  }
  return r;
}

// ── Sprint 16: the pantry the engine plans from ─────────────────────────
// `DE.availableFoods` is the list of food ids the user says they actually
// have. It is referenced 41 times across 7 engine files, and the Egyptian
// intelligence layer keys its every decision off it:
//
//   function _userSelected(food){ return DE.availableFoods.indexOf(food.id) !== -1 }
//
// This host never set it, so it stayed `[]` forever: `_userSelected` was
// always false, every food fell down the penalty branch (snacks -800,
// processed cheese -22) and nothing was ever rewarded. The Egyptian brain was
// loaded but blind, which is exactly why the produced meals looked like a
// scavenged pile instead of a real Egyptian meal.
//
// Passing an explicit list = the user's own pantry selection.
// Passing nothing = the whole catalog, which mirrors the website's
// "select all visible" and is a truthful superset -- never an empty pantry.
function applyAvailableFoods(c, inputs){
  var i = inputs || {};
  var catalog = c.__EF_FOOD_CATALOG || [];
  var known = Object.create(null);
  for (var n = 0; n < catalog.length; n++) known[catalog[n].id] = true;

  var requested = Array.isArray(i.availableFoods) ? i.availableFoods : null;
  var ids = [];
  if (requested && requested.length) {
    // Only ids the catalog really contains: a stale id from an old phone
    // cache must not silently shrink the pantry to nothing.
    for (var k = 0; k < requested.length; k++) {
      var id = String(requested[k]);
      if (known[id]) ids.push(id);
    }
  }
  if (!ids.length) {
    for (var m = 0; m < catalog.length; m++) ids.push(catalog[m].id);
  }
  // Must go through the in-bundle setter: see the pantry bridge note in
  // buildContext. A host-side assignment cannot reach a lexical `const DE`.
  var landed = -1;
  try { if (typeof c.__EF_SET_AVAILABLE === 'function') landed = c.__EF_SET_AVAILABLE(ids); } catch (e) {}
  if (landed !== ids.length) {
    // Fail loudly rather than serve a plan built from a pantry we never set:
    // a silent miss here is exactly the bug that produced nonsense meals.
    throw new Error('engine_pantry_not_applied:' + landed + '/' + ids.length);
  }
  return ids.length;
}

// ── Request isolation ────────────────────────────────────────
// Restore the engine to pristine per-request state BEFORE each compute so no
// field survives from the previous caller. Covers the top-level DE state
// object (via the in-bundle reset) and the localStorage shim.
function resetEngineState(c){
  try { if (typeof c.__EF_RESET_DE === 'function') c.__EF_RESET_DE(); } catch(e){}
  try { if (c.localStorage && typeof c.localStorage.clear === 'function') c.localStorage.clear(); } catch(e){}
}

function computeTargets(profile, inputs){
  assertProfile(profile, 'computeTargets');
  currentInputs = inputs || {};
  const c = ctx();
  resetEngineState(c);
  applyAvailableFoods(c, inputs);
  let r;
  try { r = c.NutritionEngine.calculate(profile || {}); }
  finally { currentInputs = {}; }
  r = applyCoachAdjustment(profile || {},
    applyAgePolicy(profile || {}, assertTargets(r, 'computeTargets')));
  return assertTargets(r, 'computeTargets:agePolicy');
}


// ---------------------------------------------------------------------------
//  طبقة خبير التغذية — قرار حقيقي مش مجرد نصيحة معروضة.
//  المدرب الذكي (diet-periodization + plateau-diagnostics) بيقرر أسبوعيًا
//  رقم سعرات جديد (زيادة/تقليل/تثبيت)، والرقم ده بيتحفظ ويتحقن هنا
//  في بناء الخطة الجاية. قبل كده القرار كان بيتعرض في الواجهة والوجبات
//  تفضل مبنية على الرقم القديم — يعني ديكور.
//  حدود الأمان: ±20% من رقم الماتور، ممنوع تحت أرضية السن،
//  البروتين مابيتمسش (حماية العضل)، والفرق يتوزع كارب/دهون
//  مع أرضية دهون 0.5 جم/كجم (هرمونات).
function applyCoachAdjustment(profile, targets) {
  if (!targets) return targets;
  const want = Number(profile && profile.coachTargetCals);
  const base = Number(targets.targetCals);
  if (!isFinite(want) || want <= 0 || !isFinite(base) || base <= 0) return targets;
  const lo = Math.round(base * 0.80), hi = Math.round(base * 1.20);
  let next = Math.max(lo, Math.min(hi, Math.round(want)));
  const floorCals = Number((targets.ageRules && targets.ageRules.calorieFloor) || 1200);
  if (isFinite(floorCals) && next < floorCals) next = floorCals;
  if (next === base) return targets;
  const out = Object.assign({}, targets);
  out.targetCals = next;
  out.coachAdjusted = { from: base, to: next, deltaCals: next - base };
  const m = Object.assign({}, out.macros || {});
  const pro = Number(m.protein) || 0;
  const carb = Number(m.carbs != null ? m.carbs : m.carb) || 0;
  const fat = Number(m.fat) || 0;
  if (pro > 0 || carb > 0 || fat > 0) {
    const weight = Number(profile && profile.weight) || 0;
    let dCals = next - base;
    let dCarb = Math.round((dCals * 0.55) / 4);
    let dFat = Math.round((dCals * 0.45) / 9);
    let nCarb = Math.max(0, carb + dCarb);
    let nFat = fat + dFat;
    const fatFloor = weight > 0 ? Math.round(weight * 0.5) : 30;
    if (nFat < fatFloor) {
      const lostCals = (fatFloor - nFat) * 9;
      nFat = fatFloor;
      nCarb = Math.max(0, nCarb - Math.round(lostCals / 4));
    }
    m.protein = pro;                 // البروتين ثابت دايمًا
    if (m.carbs != null) m.carbs = nCarb; else m.carb = nCarb;
    m.fat = nFat;
    out.macros = m;
  }
  return out;
}

// ---------------------------------------------------------------------------
//  طبقة سياسة السن — بتتطبق فوق ناتج الماتور مش جواه.
//  الماتور اتبنى للبالغين: Mifflin-St Jeor (متحقق 18-78) وعجز لغاية 25%
//  وبروتين لغاية 2.2 جم/كجم. ده مقبول لشاب 25 وخطر على ولد 12.
//  بدل ما نعدل الماتور (وهو مرجع الموقع)، بنفرض الحدود الآمنة بعده.
function applyAgePolicy(profile, targets) {
  const AGE = require('./age-policy');
  const age = Number(profile.age);
  const tier = AGE.tierFor(age);
  if (!tier || !targets) return targets;

  const weight = Number(profile.weight) || 0;
  const goalRaw = String(profile.goal || '').trim().toLowerCase();
  const isGain = /muscle|gain|bulk|\u062a\u0636\u062e\u064a\u0645|\u0632\u064a\u0627\u062f\u0629/.test(goalRaw);
  const isCut  = /cut|lose|loss|\u062a\u0646\u0634\u064a\u0641|\u062a\u062e\u0633\u064a\u0633|\u062e\u0633\u0627\u0631\u0629/.test(goalRaw);
  const out = Object.assign({}, targets);
  out.ageTier = tier.key;
  out.ageTierLabel = tier.label;
  out.ageNotes = [];

  // 1) تحت 18: Mifflin مش متحقق علميا — بنستخدم Schofield (FAO/WHO).
  if (tier.useSchofield && weight > 0) {
    const bmr = AGE.schofieldBMR(age, weight, profile.gender);
    if (bmr && isFinite(bmr) && bmr > 0) {
      const ratio = out.bmr > 0 ? (bmr / out.bmr) : 1;
      out.bmr = bmr;
      if (isFinite(out.tdee) && ratio > 0) out.tdee = Math.round(out.tdee * ratio);
      if (isFinite(out.targetCals) && ratio > 0) out.targetCals = Math.round(out.targetCals * ratio);
      out.ageNotes.push('\u0627\u0644\u062d\u0633\u0627\u0628 \u0628\u0645\u0639\u0627\u062f\u0644\u0629 Schofield \u0627\u0644\u0645\u0639\u062a\u0645\u062f\u0629 \u0644\u0644\u0623\u0637\u0641\u0627\u0644 \u0648\u0627\u0644\u0645\u0631\u0627\u0647\u0642\u064a\u0646 \u0628\u062f\u0644 \u0645\u0639\u0627\u062f\u0644\u0629 \u0627\u0644\u0628\u0627\u0644\u063a\u064a\u0646.');
    }
  }

  // 2) قفل العجز والفائض عند الحد الآمن للشريحة.
  const tdee = Number(out.tdee);
  if (isFinite(tdee) && tdee > 0 && isFinite(out.targetCals)) {
    // [OWNER-RATE-1] البالغ اللي اختار معدل نزول سريع بنحترم اختياره:
    // السقف يوسع لغاية 35% لكن الهدف ماينزلش تحت سعرات الراحة أبدا.
    var _reqRate = Number(profile && (profile.expectedWeeklyLoss || profile.weeklyRate)) || 0;
    var _bmiNow = (Number(profile.weight) > 0 && Number(profile.height) > 0)
      ? Number(profile.weight) / Math.pow(Number(profile.height) / 100, 2) : 0;
    var _maxDefPct = tier.maxDeficitPct;
    if (isCut && _reqRate >= 0.9 && age >= 18 && age < 60 && _bmiNow >= 27 && tier.maxDeficitPct >= 20) {
      _maxDefPct = 35;
    }
    const floorCals = Math.max(
      Math.round(tdee * (1 - _maxDefPct / 100)),
      Math.round(Number(out.bmr) || 0)
    );
    const ceilCals  = Math.round(tdee * (1 + tier.maxSurplusPct / 100));
    if (out.targetCals < floorCals) {
      out.targetCals = floorCals;
      out.ageNotes.push(tier.maxDeficitPct === 0
        ? '\u0641\u064a \u0627\u0644\u0633\u0646 \u062f\u0647 \u0645\u0641\u064a\u0634 \u0639\u062c\u0632 \u0633\u0639\u0631\u0627\u062a \u062e\u0627\u0644\u0635 \u2014 \u0627\u0644\u0647\u062f\u0641 \u0623\u0643\u0644 \u0645\u062a\u0648\u0627\u0632\u0646 \u0648\u062d\u0631\u0643\u0629.'
        : '\u0627\u0644\u0639\u062c\u0632 \u0627\u062a\u0642\u0641\u0644 \u0639\u0646\u062f ' + tier.maxDeficitPct + '% \u0639\u0634\u0627\u0646 \u0627\u0644\u0646\u0645\u0648 \u0645\u0627\u064a\u062a\u0623\u062b\u0631\u0634.');
    } else if (out.targetCals > ceilCals) {
      out.targetCals = ceilCals;
      out.ageNotes.push('\u0627\u0644\u0641\u0627\u0626\u0636 \u0627\u062a\u0642\u0641\u0644 \u0639\u0646\u062f ' + tier.maxSurplusPct + '% \u2014 \u0632\u064a\u0627\u062f\u0629 \u0623\u0633\u0631\u0639 \u0645\u0646 \u0643\u062f\u0647 \u0628\u062a\u0628\u0642\u0649 \u062f\u0647\u0648\u0646 \u0645\u0634 \u0639\u0636\u0644.');
    }

    // الولد اللي محتاج يزيد: الماتور كان بيديه سعرات صيانة بالظبط
    // (صفر فائض) يعني ماكانش هيزيد أبدا. النقص في الوزن في سن النمو
    // مشكلة صحية زي الزيادة بالظبط، فلازم فائض حقيقي محسوب.
    if (isGain && tier.allowSurplus && tier.maxSurplusPct > 0) {
      const minGain = Math.round(tdee * 1.05);
      if (out.targetCals < minGain) {
        out.targetCals = Math.min(minGain, ceilCals);
        out.ageNotes.push('\u0627\u062a\u0632\u0627\u062f \u0641\u0627\u0626\u0636 \u0622\u0645\u0646 \u0639\u0634\u0627\u0646 \u0627\u0644\u0632\u064a\u0627\u062f\u0629 \u062a\u062d\u0635\u0644 \u0641\u0639\u0644\u0627 \u2014 \u0633\u0639\u0631\u0627\u062a \u0627\u0644\u0635\u064a\u0627\u0646\u0629 \u0644\u0648\u062d\u062f\u0647\u0627 \u0645\u0627\u0628\u062a\u0632\u0648\u062f\u0634 \u0648\u0632\u0646.');
      }
    }
  }

  // 3) أرضية سعرات مطلقة — AAP/AND: ممنوع النزول تحتها للصغير.
  if (isFinite(out.targetCals) && out.targetCals < tier.calorieFloor) {
    out.targetCals = tier.calorieFloor;
    out.ageNotes.push('\u0627\u0644\u062d\u062f \u0627\u0644\u0623\u062f\u0646\u0649 \u0627\u0644\u0622\u0645\u0646 \u0641\u064a \u0627\u0644\u0633\u0646 \u062f\u0647 ' + tier.calorieFloor + ' \u0633\u0639\u0631\u0629 \u064a\u0648\u0645\u064a\u0627.');
  }

  // [OWNER-RATE-1] شفافية المعدل: بنقول للمتدرب المعدل الفعلي المطبق
  // بدل ما نحول هدفه في السر لمعدل أقل.
  if (isFinite(out.targetCals) && isFinite(out.tdee) && out.tdee > 0) {
    var _rq = Number(profile && (profile.expectedWeeklyLoss || profile.weeklyRate)) || 0;
    if (_rq > 0 && isCut) {
      var _appliedDeficit = Math.max(0, Math.round(out.tdee) - Math.round(out.targetCals));
      var _appliedRate = Math.round((_appliedDeficit * 7 / 7700) * 100) / 100;
      out.rateRequested = _rq;
      out.rateApplied = _appliedRate;
      out.rateHonored = _appliedRate + 0.05 >= _rq;
      if (!out.rateHonored) {
        out.ageNotes.push('المعدل المطبق فعلا ' + _appliedRate + ' كجم/أسبوع من أصل ' + _rq + ' — أسرع من كده ينزلك تحت سعرات الراحة.');
      }
    }
  }

  // 4) البروتين: مراهق رياضي مايحتاجش 2.2 جم/كجم (GSSI ~1.5).
  if (out.macros && weight > 0 && tier.proteinPerKg) {
    const m = Object.assign({}, out.macros);
    const minP = Math.round(tier.proteinPerKg[0] * weight);
    const maxP = Math.round(tier.proteinPerKg[1] * weight);
    const before = Number(m.protein) || 0;
    if (before > maxP) m.protein = maxP;
    if (before < minP) m.protein = minP;
    if (m.protein !== before) {
      out.ageNotes.push('\u0627\u0644\u0628\u0631\u0648\u062a\u064a\u0646 \u0627\u062a\u0638\u0628\u0637 \u0639\u0644\u0649 ' + tier.proteinPerKg[0] + '-' + tier.proteinPerKg[1] + ' \u062c\u0645/\u0643\u062c\u0645 \u0627\u0644\u0645\u0646\u0627\u0633\u0628\u0629 \u0644\u0644\u0633\u0646.');
      // نعيد توزيع فرق السعرات على الكارب عشان الإجمالي يفضل مظبوط.
      const deltaCals = (before - m.protein) * 4;
      m.carbs = Math.max(0, Math.round((Number(m.carbs) || 0) + deltaCals / 4));
    }
    out.macros = m;
  }
  // للبالغ الذي يخسر دهونًا ويتمرن مقاومة: نعتمد الوزن المستهدف بدل
  // تضخيم البروتين على وزن السمنة، مع أرضية 1.8 جم/كجم لحماية الكتلة العضلية.
  if (out.macros && isCut && age >= 18) {
    const targetWeight = Number(profile.target || profile.targetWeight) || 0;
    if (targetWeight > 0 && targetWeight < weight) {
      const m = Object.assign({}, out.macros);
      const before = Number(m.protein) || 0;
      const floor = Math.round(targetWeight * 1.8);
      if (before < floor) {
        m.protein = floor;
        m.carbs = Math.max(0, Math.round((Number(m.carbs) || 0) - (floor - before)));
        out.macros = m;
        out.ageNotes.push('البروتين اتثبت على 1.8 جم/كجم من الوزن المستهدف لحماية العضلات أثناء خسارة الدهون.');
      }
    }
  }

  // الرسالة لازم تناسب الهدف. الولد اللي بيزود ماينفعش يقرا كلام عن الخسارة.
  if (AGE.isYouth(age)) {
    if (isGain) {
      out.ageNotes.push(tier.key === 'child'
        ? '\u0641\u064a \u0627\u0644\u0633\u0646 \u062f\u0647 \u0627\u0644\u0632\u064a\u0627\u062f\u0629 \u0628\u062a\u064a\u062c\u064a \u0645\u0646 \u0623\u0643\u0644 \u0643\u0627\u0645\u0644 \u0648\u0645\u0646\u062a\u0638\u0645 \u0648\u0646\u0648\u0645 \u0643\u0648\u064a\u0633 \u2014 \u0645\u0641\u064a\u0634 \u062d\u0627\u062c\u0629 \u0627\u0633\u0645\u0647\u0627 \u062a\u0636\u062e\u064a\u0645 \u0644\u0637\u0641\u0644.'
        : '\u0627\u0644\u0632\u064a\u0627\u062f\u0629 \u0647\u0646\u0627 \u0628\u062a\u0643\u0648\u0646 \u0628\u0637\u064a\u0626\u0629 \u0648\u062b\u0627\u0628\u062a\u0629 \u0645\u0639 \u062a\u062f\u0631\u064a\u0628 \u0645\u0642\u0627\u0648\u0645\u0629 \u2014 \u0627\u0644\u0633\u0631\u0639\u0629 \u0628\u062a\u062f\u064a \u062f\u0647\u0648\u0646 \u0645\u0634 \u0639\u0636\u0644.');
    } else if (isCut) {
      out.ageNotes.push(tier.key === 'child'
        ? '\u0641\u064a \u0627\u0644\u0633\u0646 \u062f\u0647 \u0645\u0641\u064a\u0634 \u0631\u064a\u062c\u064a\u0645 \u2014 \u0627\u0644\u0647\u062f\u0641 \u0623\u0643\u0644 \u0645\u062a\u0648\u0627\u0632\u0646 \u0648\u062d\u0631\u0643\u0629 \u064a\u0648\u0645\u064a\u0629.'
        : '\u0627\u0644\u062e\u0633\u0627\u0631\u0629 \u0647\u0646\u0627 \u0628\u062a\u062d\u0635\u0644 \u0628\u062b\u0628\u0627\u062a \u0627\u0644\u0648\u0632\u0646 \u0645\u0639 \u0632\u064a\u0627\u062f\u0629 \u0627\u0644\u0637\u0648\u0644\u060c \u0645\u0634 \u0628\u0631\u064a\u062c\u064a\u0645 \u0642\u0627\u0633\u064a.');
    }
    if (tier.requiresGuardianConsent) {
      out.ageNotes.push('\u0627\u0644\u062e\u0637\u0629 \u062f\u064a \u0644\u0627\u0632\u0645 \u062a\u0643\u0648\u0646 \u0628\u0639\u0644\u0645 \u0648\u0644\u064a \u0627\u0644\u0623\u0645\u0631\u060c \u0648\u0644\u0648 \u0641\u064a\u0647 \u0623\u064a \u062d\u0627\u0644\u0629 \u0637\u0628\u064a\u0629 \u0627\u0633\u062a\u0634\u0631 \u0637\u0628\u064a\u0628 \u0627\u0644\u0623\u0637\u0641\u0627\u0644 \u0627\u0644\u0623\u0648\u0644.');
    }
  } else if (tier.note) {
    out.ageNotes.push(tier.note);
  }
  out.ageRules = {
    allowSupplements: tier.allowSupplements,
    allowMaxLifts: tier.allowMaxLifts,
    allowPlyometrics: tier.allowPlyometrics,
    allowWeights: tier.allowWeights,
    repRange: tier.repRange,
    maxSessionsPerWeek: tier.maxSessionsPerWeek,
    maxSessionMinutes: tier.maxSessionMinutes,
    restSeconds: tier.restSeconds,
    requiresGuardianConsent: tier.requiresGuardianConsent
  };
  return out;
}
// Sprint 13: the third argument (weeklyMeta) used to be hard-coded to null,
// which silently disabled 10_weekly_strategy.js -- no weekly rotation, no
// variety, no week-by-week progression. It also meant the user's chosen meal
// count never reached the planner (4 requested -> 3 produced). We now build a
// real meta object from the profile so the ORIGINAL strategy layer runs.
function buildWeeklyMeta(profile, inputs, targets){
  const p = profile || {};
  const i = inputs || {};
  const num = function(v, min, max, dflt){
    const n = Number(v);
    if (!Number.isFinite(n)) return dflt;
    return Math.max(min, Math.min(max, Math.round(n)));
  };
  // Meal count: explicit profile value wins, then the engine input id, else 4.
  const mealCount = num(p.mealCount != null ? p.mealCount : i['inp-meals'], 2, 8, 4);
  // Rotate the plan across a 4-week cycle so the same foods do not repeat.
  const week = num(p.week != null ? p.week : i['inp-week'], 1, 52, 1);
  // [EGY-v70] يوم الدورة (0..3) — بيتحقن من الـ API حسب توقيت بلد الحساب.
  const dayOfCycle = num(p.dayOfCycle != null ? p.dayOfCycle : i['dayOfCycle'], 0, 6, 0);
  return {
    week: week,
    dayOfCycle: dayOfCycle,
    cycleWeek: ((week - 1) % 4) + 1,
    meals: mealCount,
    mealCount: mealCount,
    mealsPerDay: mealCount,
    diet: String(p.diet || i['inp-diet'] || 'balanced'),
    goal: String(p.goal || ''),
    calories: targets && targets.targetCals,
    macros: (targets && targets.macros) || null,
    health: Array.isArray(p.healthConditions) ? p.healthConditions : [],
    budget: String(p.budget || i['inp-budget'] || 'mid'),
    variety: true
  };
}

function _efUserSeed(p){
  p = p || {};
  var s = String(p.gender||'')+'|'+(p.age||0)+'|'+(p.height||0)+'|'+(p.weight||0)+'|'+(p.target||0)+'|'+(p.goal||'')+'|'+(p.selectedDiet||p.diet||'');
  var h = 0; for (var i=0;i<s.length;i++){ h = ((h<<5)-h + s.charCodeAt(i))|0; }
  return ((h%997)+997)%997;
}

function computeMealPlan(profile, inputs){
  assertProfile(profile, 'computeMealPlan');
  const c = ctx();
  // ── Therapeutic pantry pruning (Egyptian clinical layer) ──
  // When the trainee reports health conditions we restrict the pantry the
  // engine plans from to foods that PASS every active condition's rule, so the
  // AUTOMATIC plan never pushes something unsafe (e.g. white rice/dates for a
  // diabetic, offal/sardines for gout, pickles/rennge for hypertension). This
  // only affects auto-suggestions; the picker still lets a user pick manually.
  const health0 = Array.isArray(profile && profile.healthConditions) ? profile.healthConditions : [];
  let effInputs = inputs || {};
  if (health0.length) {
    const cat = c.__EF_FOOD_CATALOG || [];
    const allowedSet = Object.create(null);
    for (let fi = 0; fi < cat.length; fi++) { if (passesHealth(cat[fi], health0)) allowedSet[cat[fi].id] = true; }
    const req = (Array.isArray(effInputs.availableFoods) && effInputs.availableFoods.length)
      ? effInputs.availableFoods : Object.keys(allowedSet);
    const pruned = req.map(String).filter(function(id){ return allowedSet[id]; });
    effInputs = Object.assign({}, effInputs, { availableFoods: pruned.length ? pruned : Object.keys(allowedSet) });
  }
  currentInputs = effInputs;
  resetEngineState(c);
  const pantrySize = applyAvailableFoods(c, effInputs);
  let targets, plan = null, meta = null;
  try {
    // [FIX-AGEPOLICY-PLAN] طبقة السن وقرار المدرب كانو مطبقين في computeTargets بس،
    // فالخطة الفعلية (الوجبات) كانت بتتبني على الرقم الخام من الماتور من غير
    // أرضية السن ولا تعديل خبير التغذية — دلوقتي المسارين متطابقين.
    targets = applyCoachAdjustment(profile || {},
      applyAgePolicy(profile || {}, c.NutritionEngine.calculate(profile || {})));
    // Guard BEFORE building meals: never plan food around a NaN target.
    assertTargets(targets, 'computeMealPlan');
    meta = buildWeeklyMeta(profile, effInputs, targets);
    // [EGY-v70] احقن بذرة اليوم/الأسبوع في DE قبل بناء الوجبات (DE لكسيكال).
    try { if (typeof c.__EF_SET_DAYSEED === 'function') c.__EF_SET_DAYSEED(meta.week, meta.dayOfCycle); } catch(e){}
    // [FIX-VARIETY] احقن بصمة المستخدم عشان دورات التنويع تختلف من شخص لآخر (بياناته + دايته).
    try { if (typeof c.__EF_SET_USERSEED === 'function') c.__EF_SET_USERSEED(_efUserSeed(profile)); } catch(e){}
    // NOTE: routing meal composition through the v50 Egyptian templates
    // (__EF_TEMPLATE_BSMP / SMPS.ensurePlan) is the planned fix for meal
    // pairing + portion realism, but the template builder returns a different
    // data shape and needs a dedicated, fully-tested adapter. Until that lands
    // we keep the working structured builder so plans never break.
    var _bsmp = (typeof c.buildSmartMealPlan === 'function') ? c.buildSmartMealPlan : null;
    if (_bsmp) {
      try {
        plan = _bsmp(targets.targetCals, targets.macros, meta);
      } catch(e){
        // The strategy layer is an enhancement, not a hard dependency: if it
        // throws we retry the legacy call so the user still gets a plan.
        plan = _bsmp(targets.targetCals, targets.macros, null);
        plan = plan || {};
        plan.weeklyMetaError = String((e&&e.message)||e);
      }
    }
  } finally {
    currentInputs = {};
  }
  // ── Composition realism layer (portions + Egyptian pairing rules) ──
  // Deterministic post-pass on the structured builder's output: clamp absurd
  // portions to realistic Egyptian servings, round to the nearest 5g, enforce
  // the owner's hard pairing rules, then recompute every meal + day total so the
  // numbers the user sees always add up. Best-effort: never break a plan.
  // ── Training-day pre-workout meal ───────────────────────────────
  // لو النهاردة يوم تمرين، الوجبة بتتحقن قبل طبقة التنظيف عشان إغلاق
  // السعرات يوزع اليوم كله من جديد ويفضل مطابق للهدف بالظبط.
  if (plan) {
    try {
      const _pf = profile || {};
      const _isTrain = (_pf.isTrainingDay === true || _pf.isTrainingDay === 1 || _pf.isTrainingDay === 'true');
      if (_isTrain) _efInjectPreWorkout(plan, _pf.preWorkoutVariant != null ? _pf.preWorkoutVariant : new Date().getDay());
      // [FIX-SALAD-3] شكل السلطة بيتحدد مرة واحدة لليوم ويتكرر في كل وجباته.
      plan._saladVariant = (_pf.saladVariant != null ? _pf.saladVariant
        : (_pf.preWorkoutVariant != null ? _pf.preWorkoutVariant : new Date().getDay()));
      // [FIX-BREAD-2] قاعدة العيش مربوطة بنوع الدايت — مش قاعدة عامة.
      plan._dietKey = String(_pf.diet || 'balanced');
      plan._dayOfCycle = Number(meta && meta.dayOfCycle) || 0;
      plan._weekNumber = Number(meta && meta.week) || 1;
      plan._healthConditions = Array.isArray(_pf.healthConditions) ? _pf.healthConditions.slice() : [];
    } catch(_pe){ plan.preWorkoutError = String((_pe&&_pe.message)||_pe); }
  }
  if (plan) { try { _efSanitizePlan(plan); } catch(_se){ plan.sanitizeError = String((_se&&_se.message)||_se); } }
  // ── العقل الموحّد للقواعد (المصدر الواحد) — الحَكَم الأخير على الخطة ──
  // كل قواعد الأكل (مفيش رز في الفطار، سلطة أو خضار مطبوخ مش الاتنين، مفيش
  // خضار/شوربة/بطاطس مع السمك، مفيش رز مع تونة، سقف التونة/الزبادي، حد
  // بروتينات الفطار، والعشا تكرار أخف) بتتطبّق من lib/nutrition-rules.js فقط.
  if (plan) {
    try {
      const _rules = require('./nutrition-rules');
      const _res = _rules.enforce(plan);
      plan._ruleFixes = (_res && _res.fixes) || [];
    } catch(_re){ plan.rulesError = String((_re&&_re.message)||_re); }
    // nutrition-rules may remove/cap foods, so quantity and calorie guarantees
    // must run after it as the final authority seen by Flutter and exports.
    try { _efFinalizeOwnerPlan(plan); }
    catch(_fg){ plan.finalOwnerGateError=String((_fg&&_fg.message)||_fg); }
    // Internal portion helpers are allowed to move food grams, not to invent a
    // second target. Re-pin the plan header to the canonical target object that
    // computeTargets returned for Analysis and the API response.
    plan.targetCals=Number(targets.targetCals)||Number(plan.targetCals)||0;
    plan.targetMacros=Object.assign({},targets.macros||{});
  }
  // The selected count describes normal eating occasions only. Training adds
  // one pre-workout meal outside that count. If the legacy builder collapsed
  // two snack slots (the 5-meal layout), split the existing snack instead of
  // inventing another food or adding calories.
  if (plan) {
    try { _efEnsureSelectedMealCount(plan, Math.max(2, Math.min(5, Number((profile||{}).mealCount)||3))); }
    catch(_mcErr){ plan.mealCountError=String((_mcErr&&_mcErr.message)||_mcErr); }
    // Meal-count normalization can merge/remove legacy slots, so the visible
    // final invariant must run *after* it. Running before this point allowed a
    // 2-meal plan to lose ~200 kcal after its audit had already passed.
    try {
      _efApplyWeeklyFoodRotation(plan);
      _efEnsureCookedVegRotation(plan);
      _efEnsureNaturalYogurtVariety(plan);
      _efEnsureMainMealStructure(plan);
      _efNormalizeMainCarbPairing(plan);
      const _finalRules=require('./nutrition-rules');
      const _finalRes=_finalRules.enforce(plan);
      if(_finalRes&&Array.isArray(_finalRes.fixes))
        plan._ruleFixes=(plan._ruleFixes||[]).concat(_finalRes.fixes);
    } catch(_fr){ plan.finalRulesError=String((_fr&&_fr.message)||_fr); }
    plan.targetCals=Number(targets.targetCals)||Number(plan.targetCals)||0;
    plan.targetMacros=Object.assign({},targets.macros||{});
    try { plan._nutritionAudit=require('./nutrition-plan-auditor').reconcile(plan, c.__EF_FOOD_CATALOG || []); }
    catch(_na){ plan.nutritionAuditError=String((_na&&_na.message)||_na); }
    // الـauditor قد يضيف أو ينقل أصنافا وهو يغلق فجوة السعرات؛ لذلك نعيد
    // تطبيق القواعد الصلبة ثم نعلّم الزيت/الزبدة كسطر تابع للعنصر الأساسي.
    try {
      const _lastRules=require('./nutrition-rules');
      const _last=_lastRules.enforce(plan);
      if(_last&&Array.isArray(_last.fixes)) plan._ruleFixes=(plan._ruleFixes||[]).concat(_last.fixes);
      _efEnsureMainMealStructure(plan);
      _efNormalizeMainCarbPairing(plan);
      _efEnforceEggRange(plan);
      _efEnforceOwnerServingLimits(plan);
      _efFillTwoMealEggGap(plan);
      _efFillRequestedCalorieFloor(plan);
      _efTrimDayToTolerance(plan);
      _efEnforceDailyCaps(plan);
      _efFillTwoMealDenseCarb(plan);
      _efCloseTwoMealCarbs(plan);
      _efFillRequestedCalorieFloor(plan);
      _efTrimDayToTolerance(plan);
      _efCleanFinalSnacks(plan);
      _efEnsureCookedVegRotation(plan);
      _efEnsureMainMealStructure(plan);
      _efNormalizeMainCarbPairing(plan);
      _efEnforceFatPairing(plan);
      _efEnforceOwnerServingLimits(plan);
      _efEnforceDailyCaps(plan);
      _efFillRequestedCalorieFloor(plan);
      _efTrimDayToTolerance(plan);
      _efEnforceOwnerServingLimits(plan);
      _efEnforceDailyCaps(plan);
      _efCleanFinalSnacks(plan);
      // لا تسمح لقص السعرات أو تنظيف السناك أن يعيدا وجبة رئيسية إلى عنصرين.
      _efEnsureMainMealStructure(plan);
      _efNormalizeMainCarbPairing(plan);
      _efEnforceFatPairing(plan);
      _efTrimDayToTolerance(plan);
      _efEnforceOwnerServingLimits(plan);
      _efEnforceDailyCaps(plan);
      _efCloseFinalMainGap(plan);
      _efEnforceOwnerServingLimits(plan);
      _efEnforceDailyCaps(plan);
      _efCloseFinalMainGap(plan);
      _efHardCapMeals(plan);
      _efEnsureMainMealStructure(plan);
      _efNormalizeMainCarbPairing(plan);
      var _visibleRules=require('./nutrition-rules').enforce(plan);
      if(_visibleRules&&Array.isArray(_visibleRules.fixes)) plan._ruleFixes=(plan._ruleFixes||[]).concat(_visibleRules.fixes);
      _efCloseFinalMainGap(plan);
      _efTrimDayToTolerance(plan);
      _efHardCapMeals(plan);
      var _postCapRules=require('./nutrition-rules').enforce(plan);
      if(_postCapRules&&Array.isArray(_postCapRules.fixes)) plan._ruleFixes=(plan._ruleFixes||[]).concat(_postCapRules.fixes);
      _efCloseFinalMainGap(plan);
      _efTrimDayToTolerance(plan);
      // لا يترك القص النهائي وجبة رئيسية من عنصرين فقط.
      _efEnsureMainMealStructure(plan);
      _efNormalizeMainCarbPairing(plan);
      _efTrimDayToTolerance(plan);
      // الحكم الأخير بعد كل مولدات/موازنات السعرات: لا كارب مزدوج، لا شوفان،
      // سلطة 3 مكونات، وما قبل التمرين قهوة + مصدر طاقة واحد.
      _efApplyHealthPortionAdjustments(plan);
      var _ultimateRules=require('./nutrition-rules').enforce(plan);
      if(_ultimateRules&&Array.isArray(_ultimateRules.fixes)) plan._ruleFixes=(plan._ruleFixes||[]).concat(_ultimateRules.fixes);
      _efCloseFinalMainGap(plan);
      _efBalanceFinalOneCarb(plan);
      _efTrimDayToTolerance(plan);
      var _lc=0,_lp=0,_lcb=0,_lf=0;
      for(var _lt=0;_lt<(plan.meals||[]).length;_lt++){
        var _tv=_efRecalcTotals(plan.meals[_lt]);
        _lc+=_tv.cals;_lp+=_tv.pro;_lcb+=_tv.carb;_lf+=_tv.fat;
      }
      if(plan.totals){plan.totals.cals=Math.round(_lc);plan.totals.pro=Math.round(_lp);plan.totals.carb=Math.round(_lcb);plan.totals.fat=Math.round(_lf);}
      plan._calorieGap=Math.round((Number(plan.targetCals)||0)-_lc);
      var _wm=plan.targetMacros||{},_wp=Number(_wm.protein||_wm.pro)||0,_wc=Number(_wm.carbs||_wm.carb)||0,_wf=Number(_wm.fat)||0;
      var _pct=function(a,b){return b>0?Math.round((a-b)/b*1000)/10:0;};
      plan._macroAudit={targetCals:Math.round(Number(plan.targetCals)||0),actualCals:Math.round(_lc),calorieGap:plan._calorieGap,
        targetMacros:{pro:_wp,carb:_wc,fat:_wf},actualMacros:{pro:Math.round(_lp),carb:Math.round(_lcb),fat:Math.round(_lf)},
        driftPct:{protein:_pct(_lp,_wp),carbs:_pct(_lcb,_wc),fat:_pct(_lf,_wf)}};
      plan._macroAudit.passed=Math.abs(plan._calorieGap)<=100&&(!_wp||Math.abs(plan._macroAudit.driftPct.protein)<=20)&&(!_wc||Math.abs(plan._macroAudit.driftPct.carbs)<=18)&&(!_wf||Math.abs(plan._macroAudit.driftPct.fat)<=25);
      for(var _pm=0;_pm<(plan.meals||[]).length;_pm++){
        var _mm=plan.meals[_pm]; _mm._dietKey=plan._dietKey;
        for(var _cl=0;_cl<(_mm.foods||[]).length;_cl++) if(_efIsAddedFat(_mm.foods[_cl])){
          _mm.foods[_cl]._isAddon=false; delete _mm.foods[_cl]._pairGroup; delete _mm.foods[_cl]._pairWith;
        }
        _efPairFats(_mm);
        for(var _af=0;_af<(_mm.foods||[]).length;_af++) if(_efIsAddedFat(_mm.foods[_af])&&!_mm.foods[_af]._isAddon)
          _mm.foods.splice(_af--,1);
      }
    } catch(_li){ plan.lastInvariantError=String((_li&&_li.message)||_li); }
  }
  // ── Fasting / Ramadan scheduling layer ──
  // Display + timing only: the meals, calories and macros are IDENTICAL to what
  // the engine computed; we only relabel/re-time the slots into إفطار/سحور
  // (Ramadan) or an 8-hour eating window (16:8).
  // Ramadan is applied AUTOMATICALLY, and ONLY during the actual Hijri month of
  // Ramadan (server/device date). There is no manual toggle: the إفطار/سحور
  // schedule surfaces on its own during Ramadan and disappears the rest of the
  // year. Nutrition (calories + macros) is IDENTICAL — only slot labels/timing
  // change.
  const fmode = _efIsRamadanNow() ? 'ramadan' : 'normal';
  if (fmode !== 'normal' && plan) { plan = applyMealSchedule(plan, fmode); plan.fastingMode = fmode; }
  // pantrySize is reported so the caller can prove which pantry produced the
  // plan instead of guessing.
  return { targets:targets, plan:plan, weeklyMeta:meta, pantrySize:pantrySize, healthPruned: health0.length ? true : false };
}
// ── Meal composition sanitizer (portions + pairing) ────────────────────────
// A deterministic, best-effort post-pass that makes the AUTOMATIC plan look
// like a real Egyptian coach wrote it: sane portions and the owner's hard
// pairing rules, with every total recomputed from the foods actually shown.
function _efNameOf(f){ return String((f && f.food && f.food.nameAr) || (f && f.nameAr) || (f && f.name) || '').replace(/[\u00A0\u200f\u200e\u202a-\u202e\ufeff]/g, ' ').replace(/\s+/g, ' ').trim(); }
function _efCatOf(f){ return String((f && f.food && (f.food.cat || f.food.category)) || (f && f.cat) || (f && f.category) || ''); }
function _efEnsureSelectedMealCount(plan,want){
  var meals=(plan&&plan.meals)||[];
  function core(){return meals.filter(function(m){return m&&!m._autoPreWorkout&&Array.isArray(m.foods)&&m.foods.length;});}
  var real=core(), serial=2;
  while(real.length<want){
    var source=real.find(function(m){return /snack|سناك/.test(String(m.slotKey||'')+' '+String(m.label||''))&&m.foods.length>1;});
    if(!source) source=real.slice().sort(function(a,b){return _efMealCals(b)-_efMealCals(a);})[0];
    if(!source||!source.foods||!source.foods.length)break;
    var moved=[];
    if(source.foods.length>1){
      source.foods.sort(function(a,b){return (Number(b.cals)||0)-(Number(a.cals)||0);});
      moved.push(source.foods.pop());
    }else{
      var only=source.foods[0], grams=Number(only.grams)||0;
      if(grams<10)break;
      var clone=Object.assign({},only,{food:only.food?Object.assign({},only.food):only.food});
      var half=Math.max(5,Math.round(grams/10)*5);
      _efSetGrams(only,grams-half); _efSetGrams(clone,half); moved.push(clone);
    }
    _efRecalcTotals(source);
    var extra={slotKey:'snack'+serial,label:'سناك '+serial,foods:moved,totals:{cals:0,pro:0,carb:0,fat:0}};
    _efRecalcTotals(extra);
    var dinner=meals.findIndex(function(m){return String(m&&m.slotKey)==='dinner';});
    meals.splice(dinner<0?meals.length:dinner,0,extra); serial++; real=core();
  }
}
// Realistic Egyptian per-serving ceilings, in grams.
// [OWNER-RULE v2] حدود الأطعمة على مدار اليوم كله (مش في الوجبة الواحدة).
// المكسرات + اللب + السوداني = مجموعة واحدة. الزيت + الزبدة = مجموعة واحدة.
var _EF_DAILY_CAPS = [
  { key:'nuts',     g:50,  test:function(n,c,id){ return c==='nut' || /مكسرات|لوز|كاجو|عين جمل|بندق|فستق|سوداني|لب /.test(n); } },
  { key:'fats',     g:20,  test:function(n,c,id){ return /زيت زيتون|زبدة|سمنة/.test(n) && c!=='protein'; } },
  { key:'tahina',   g:20,  test:function(n,c,id){ return /طحينة/.test(n); } },
  { key:'yogurt',   g:200, test:function(n,c,id){ return /زبادي/.test(n); } },
  { key:'tuna',     g:300, test:function(n,c,id){ return /تونة|تونه/.test(n); } },
  { key:'egg',      g:300, test:function(n,c,id){ return c==='egg'||/(^|\s)بيض(\s|$)/.test(n); } },
  { key:'roumy',    g:100, test:function(n,c,id){ return /رومي|رومى/.test(n); } },
  { key:'rouds',    g:150, test:function(n,c,id){ return /ردس|رودس/.test(n); } },
  { key:'bread',    g:200, test:function(n,c,id){ return /عيش|توست|خبز/.test(n); } },
  { key:'ricecake', g:50,  test:function(n,c,id){ return /رايس كيك|رايس كيكس/.test(n) || /rayskyk/i.test(id); } },
  { key:'choc',     g:50,  test:function(n,c,id){ return /شوكولات|شيكولات|نوتيلا|كيتكات|مندولين/.test(n) || /choc|nutella|kitkat/i.test(id); } },
  { key:'dates',    g:60,  test:function(n,c,id){ return /تمر|بلح|زبيب|قراصيا|فواكه مجففة|مشمش مجفف/.test(n); } },
  { key:'fruit',    g:300, test:function(n,c,id){ return c==='fruit' && !/تمر|بلح|زبيب|قراصيا|فواكه مجففة|مشمش مجفف/.test(n); } },
  { key:'honey',    g:30,  test:function(n,c,id){ return /عسل|مربى|حلاوة طحينية|حلاوه طحينيه/.test(n); } },
  { key:'fatcheese',g:100, test:function(n,c,id){ return /شيدر|فلمنك|موتزاريلا|موزاريلا|جبنة صفرا/.test(n); } }
];
function _efDailyGroup(f){
  var n=_efNameOf(f), c=_efCatOf(f), id=String((f&&f.food&&f.food.id)||(f&&f.id)||'');
  for(var i=0;i<_EF_DAILY_CAPS.length;i++){ if(_EF_DAILY_CAPS[i].test(n,c,id)) return _EF_DAILY_CAPS[i]; }
  return null;
}
function _efDietKey(plan){ return String((plan&&(plan._dietKey||plan.diet))||'balanced').toLowerCase(); }
function _efIsKetoPlan(plan){ return _efDietKey(plan)==='keto'; }
function _efAddedFatDayMax(plan){ return _efIsKetoPlan(plan)?50:20; }
function _efAddedFatItemMax(plan){ return _efIsKetoPlan(plan)?25:10; }
// سقف نصيب الوجبة من سعرات اليوم: رئيسية 35% (50% لو وجبتين)، سناك ≤20%.
function _efSlotShareCeil(meal, realCount){
  var sk=String((meal&&meal.slotKey)||'')+' '+String((meal&&meal.label)||'');
  var base = realCount<=2 ? 0.50 : 0.35;
  if(/snack|سناك|تحلية|قبل التمرين|بعد التمرين|pre|post/i.test(sk)) return Math.min(base, 0.20);
  return base;
}
// الأكل الأساسي القابل للتكبير لتغطية السعرات (مش خضار/دهون مضافة/صنف ليه حد يومي).
function _efIsMainGrowable(f){
  if(_efIsVegF(f)) return false;
  if(_efIsAddedFat(f)) return false;
  if(_efDailyGroup(f)) return false;
  var per=(f&&f.food&&f.food.cal!=null)?Number(f.food.cal):0;
  return per>0;
}
// كبّر الأكل الأساسي لحد ما اليوم يوصل الهدف مع احترام سقف نصيب كل وجبة.
function _efGrowMainsToTarget(plan){
  var meals=(plan&&plan.meals)||[];
  var tgt=Number(plan.targetCals)||0; if(!tgt) return;
  var realCount=meals.filter(function(m){return m&&!m._autoPreWorkout&&((m.foods||[]).length>0);}).length;
  function day(){ var t=0; for(var i=0;i<meals.length;i++) t+=_efMealCals(meals[i]); return t; }
  function hasGrowable(meal){ var fs=meal.foods||[]; for(var i=0;i<fs.length;i++){ var f=fs[i]; if(_efIsMainGrowable(f) && (Number(f.grams)||0) < _efPortionCap(f)-2) return true; } return false; }
  var guard=0;
  while(day()<tgt*0.985 && guard++<120){
    var moved=false;
    for(var mi=0; mi<meals.length; mi++){
      var meal=meals[mi]; if(!meal||meal._autoPreWorkout) continue;
      var lim=tgt*_efSlotShareCeil(meal, realCount);
      if(_efMealCals(meal) >= lim-5) continue;
      var fs=meal.foods||[];
      for(var fj=0; fj<fs.length; fj++){
        if(day()>=tgt*0.985) break;
        var f=fs[fj]; if(!_efIsMainGrowable(f)) continue;
        var per=(f.food&&f.food.cal!=null)?Number(f.food.cal):0; if(!per)continue;
        var cap=_efPortionCap(f); var cur=Number(f.grams)||0; if(cur>=cap) continue;
        var room=lim-_efMealCals(meal); if(room<10) break;
        var wantCal=Math.min(tgt-day(), room);
        var add=Math.round(wantCal/per*100); add=Math.round(add/5)*5; if(add<5) add=5;
        if(cur+add>cap) add=Math.floor((cap-cur)/5)*5;
        if(add<5) continue;
        var b=Number(f.cals)||0; _efSetGrams(f,cur+add); if((Number(f.cals)||0)>b) moved=true;
      }
    }
    if(!moved) break;
  }
}
// فرض الحدود اليومية: اجمع جرامات كل مجموعة عبر كل الوجبات، ولو زادت قصّ الأكبر.
function _efEnforceDailyCaps(plan){
  var meals=(plan&&plan.meals)||[];
  for(var gi=0; gi<_EF_DAILY_CAPS.length; gi++){
    var grp=_EF_DAILY_CAPS[gi];
    var groupMax=grp.key==='fats'?_efAddedFatDayMax(plan):grp.g;
    var entries=[], total=0;
    for(var mi=0; mi<meals.length; mi++){
      var fs=(meals[mi]&&meals[mi].foods)||[];
      for(var fj=0; fj<fs.length; fj++){ if(_efDailyGroup(fs[fj])===grp){ entries.push(fs[fj]); total+=Number(fs[fj].grams)||0; } }
    }
    if(total<=groupMax) continue;
    var over=total-groupMax;
    entries.sort(function(a,b){ return (Number(b.grams)||0)-(Number(a.grams)||0); });
    for(var ei=0; ei<entries.length && over>0.5; ei++){
      var f=entries[ei]; var cur=Number(f.grams)||0; var cut=Math.min(cur, over);
      _efSetGramsFine(f, cur-cut); over-=cut;
    }
    for(var mk=0; mk<meals.length; mk++){
      var mm=meals[mk]; if(!mm||!Array.isArray(mm.foods)) continue;
      mm.foods=mm.foods.filter(function(x){ return !(_efDailyGroup(x)===grp && (Number(x.grams)||0)<=0); });
    }
  }
  for(var r=0;r<meals.length;r++){ _efRecalcTotals(meals[r]); }
}

function _efPortionCap(f){
  const n = _efNameOf(f); const cat = _efCatOf(f);
  const has = function(s){ return n.indexOf(s) !== -1; };
  // حدود الوجبة تسبق الحدود اليومية: البيض والفول لا يجوز تكبيرهما لإغلاق السعرات.
  if (has('بيض') && !has('جبنة بيضاء')) return 150;
  if (has('فول') && !has('سوداني')) return 200;
  if (/جبنة رومي|جبنه رومي/.test(n)) return 70;
  if (/جبنة رودس|جبنه رودس/.test(n)) return 200;
  if (/جبنة قريش|جبنه قريش|جبنة بيضاء|جبنه بيضاء/.test(n)) return 150;
  // الأصناف اللي ليها حد يومي: سقف الوجبة الواحدة = مخصص اليوم كله (والحد اليومي بيتفرض بره).
  var grp = _efDailyGroup(f);
  if (grp) return grp.g;
  if (cat === 'carb' || has('رز') || has('أرز') || has('مكرونة') || has('بطاطس')) return 600;
  if (cat === 'protein' || cat === 'protein_chicken' || cat === 'protein_meat' || cat === 'fish') return 250;
  if (cat === 'dairy' || has('جبنة')) return 250;
  if (cat === 'fruit') return 300;
  if (cat === 'fat') return 50;
  if (cat === 'veg' || cat === 'vegetable' || cat === 'vegetables') return 500;
  return 400;
}
// Set grams and recompute macros from the per-100g base. Whole foods use 5g
// steps; added oil/butter use exact 1g steps in the approved 2..10g range.
function _efSetGrams(f, g){
  var _fineFat = _efIsAddedFat(f);
  g = _fineFat
    ? Math.max(2, Math.min(Number(f._addonMaxGrams)||10, Math.round(g)))
    : Math.max(5, Math.round(g / 5) * 5);
  const oldG = Number(f.grams) || 0;
  const base = f.food || null;
  f.grams = g;
  const R1 = function(x){ return Math.round(x * 10) / 10; };
  if (base && base.cal != null) {
    f.cals = Math.round((Number(base.cal) || 0) * g / 100);
    if (base.pro != null) f.pro = R1((Number(base.pro) || 0) * g / 100);
    if (base.carb != null) f.carb = R1((Number(base.carb) || 0) * g / 100);
    if (base.fat != null) f.fat = R1((Number(base.fat) || 0) * g / 100);
  } else if (oldG > 0) {
    const r = g / oldG;
    if (f.cals != null) f.cals = Math.round((Number(f.cals) || 0) * r);
    if (f.pro != null) f.pro = R1((Number(f.pro) || 0) * r);
    if (f.carb != null) f.carb = R1((Number(f.carb) || 0) * r);
    if (f.fat != null) f.fat = R1((Number(f.fat) || 0) * r);
  }
  if (f.calories != null) f.calories = (f.cals != null ? f.cals : f.calories);
}
function _efIsBreakfast(meal){ return /فطار|فطور|إفطار|breakfast/.test(String((meal && meal.slotKey) || '') + ' ' + String((meal && meal.label) || '')); }
function _efMealHas(names, token){ for (var i = 0; i < names.length; i++){ if (names[i].indexOf(token) !== -1) return true; } return false; }
// Return true to KEEP a food, false to drop it (owner's hard pairing rules).
function _efPairingKeep(f, names, meal){
  const n = _efNameOf(f);
  // وجبة قبل التمرين مقفولة ومظبوطة بالإيد. ماتتلمسش
  if (meal && meal._autoPreWorkout) return true;
  const breakfast = _efIsBreakfast(meal);
  const slot = String((meal && meal.slotKey) || '');
  const isSnack = slot === 'snack' || /سناك|تحلية/.test(String((meal && meal.label) || ''));
  const hasCarbMain = _efMealHas(names,'رز') || _efMealHas(names,'أرز') || _efMealHas(names,'عيش') || _efMealHas(names,'مكرونة');
  const hasGrill = _efMealHas(names,'مشوي') || _efMealHas(names,'مشوية');
  const hasCookedVeg = _efMealHas(names,'مطبوخ') || _efMealHas(names,'فاصوليا') || _efMealHas(names,'بسلة') || _efMealHas(names,'بسله') || _efMealHas(names,'لوبيا') || _efMealHas(names,'ملوخية') || _efMealHas(names,'كوسة') || _efMealHas(names,'بامية') || _efMealHas(names,'باذنجان') || _efMealHas(names,'خضار مشكل') || _efMealHas(names,'شوربة') || _efMealHas(names,'عدس') || _efMealHas(names,'قلقاس');
  const hasFoolOrFriedEgg = _efMealHas(names,'فول مدمس') || _efMealHas(names,'بيض مقلي');
  const hasCheeseOrEgg = _efMealHas(names,'جبنة') || _efMealHas(names,'بيض');
  // [OWNER-RULE] الفطار مصري: ممنوع رز أو مكرونة في الفطار خالص.
  if (breakfast && (n.indexOf('رز') !== -1 || n.indexOf('أرز') !== -1 || n.indexOf('مكرونة') !== -1)) return false;
  if (breakfast && n.indexOf('فاصوليا') !== -1) return false;                          // no cooked fasolia at breakfast
  // [OWNER-RULE] السناك: ممنوع الجبنة القريش خالص، السناك فاكهة/
  // زبادي/شوكولاتة دارك/مكسرات أو بدائل زي الترمس/الفشار.
  if (isSnack && n.indexOf('قريش') !== -1) return false;
  if (n.indexOf('حمص') !== -1 && hasCarbMain) return false;                             // chickpeas only alongside salad
  if (n.indexOf('طحينة') !== -1 && (!hasGrill || hasCookedVeg)) return false;                             // tahini only with grills
  if (n.indexOf('فول سوداني') !== -1 && hasCheeseOrEgg) return false;                    // peanut butter never with cheese/egg
  if (n.indexOf('زبدة') !== -1 && n.indexOf('فول سوداني') === -1 && !hasFoolOrFriedEgg) return false; // butter only w/ fool or fried egg
  // [OWNER-RULE] زيت الزيتون مرتبط بالسلطة والجبنة والفول المدمس فقط.
  if (n.indexOf('زيت زيتون') !== -1) {
    const okZeit = _efMealHas(names,'سلطة') || _efMealHas(names,'فول مدمس') ||
      _efMealHas(names,'جبنة قريش') || _efMealHas(names,'جبنة بيضاء') || _efMealHas(names,'جبنة رودس') ||
      _efMealHas(names,'كبدة إسكندراني') || _efMealHas(names,'كبد وقوانص');
    if (!okZeit) return false;
  }
  // [FIX-R2] قواعد المطبخ المصري اللي كانت متكتوبة في 25_owner_rules_post.js بس
  // مكانتش بتتنفّذ (الموديول بيقرا portions/slot والخطة الحقيقية foods/slotKey،
  // وكمان الهوست بينده buildSmartMealPlan مباشرة). بنرجّع تنفيذها هنا في الطبقة
  // اللي فعلاً بتشتغل على الخطة النهائية. مااخترعناش قاعدة — رجّعنا تطبيق الموجود.
  var _slotMain = (slot === 'lunch' || slot === 'dinner' || breakfast);
  if (_slotMain) {
    // (أ) [#2/#4] عناصر السناك (سوداني/مكسرات/لب/بذور/ترمس/فشار/شوكولاتة/جرانولا)
    //     والتمر/الفاكهة ممنوعة جوه الوجبات الرئيسية — مكانها السناك وقبل/بعد التمرين.
    var _cf = _efCatOf(f);
    if (_cf === 'nut' || _cf === 'snack') return false;
    if (/سوداني|كاجو|كاشو|لوز|بندق|فستق|عين جمل|بيكان|بيكن|مكسرات|ترمس|فشار|شوكولات|شيكولات|جرانولا|بذور|لب أبيض|لب ابيض|لب سوري|لب قرع|لب سوبر|لب /.test(n)) return false;
    if ((_cf === 'fruit' || n.indexOf('تمر') !== -1 || n.indexOf('بلح') !== -1) &&
        !(slot === 'dinner' && meal && meal._lightFruitYogurt && _cf === 'fruit')) return false;
  }
  // (ب) [#6] السمك ما بيجيش معاه خضار مطبوخ — سلطة + عيش/رز أو طحينة بس.
  //     الخضار المطبوخ يبقى جنب اللحمة/الفراخ بس.
  var _hasFish = _efMealHas(names,'سمك') || _efMealHas(names,'بلطي') || _efMealHas(names,'بوري') ||
    _efMealHas(names,'ماكريل') || _efMealHas(names,'سردين') || _efMealHas(names,'تونة') ||
    _efMealHas(names,'سلمون') || _efMealHas(names,'بلاميط') || _efMealHas(names,'قاروص') || _efMealHas(names,'دنيس');
  if (_hasFish && _efCatOf(f) !== 'protein' &&
      /فاصوليا|بسلة|بسله|لوبيا|ملوخية|كوسة|بامية|باذنجان|خضار مشكل|خضار مطبوخ|شوربة عدس|عدس/.test(n)) return false;
  // (ج) [#6] التونة ما تتحطش تلقائياً مع الرز — تبقى مع العيش/السلطة.
  if (_efMealHas(names,'تونة') && (n.indexOf('رز') !== -1 || n.indexOf('أرز') !== -1)) return false;
  return true;
}
// [OWNER-RULE] ربط الزيت/الزبدة بالعنصر المرتبط به للعرض inline (بيض + زبدة)
// بدل سطر منفصل. بنسيب العنصر في الماكروز زي ما هو (محسوب) بس بنعلّمه
// بالعنصر اللي يتعرض جنبه عشان الموبايل يدمجهم في سطر واحد.
function _efPairFats(meal){
  const foods = (meal && meal.foods) || [];
  if (foods.length < 2) return;
  const findMain = function(tokens){
    for (var i = 0; i < foods.length; i++){
      const nm = _efNameOf(foods[i]);
      for (var t = 0; t < tokens.length; t++){ if (nm.indexOf(tokens[t]) !== -1) return foods[i]; }
    }
    return null;
  };
  for (var i = 0; i < foods.length; i++){
    const nm = _efNameOf(foods[i]);
    let main = null;
    if (nm.indexOf('زبدة') !== -1 && nm.indexOf('فول سوداني') === -1){
      main = findMain(['بيض مقلي','بيض','فول مدمس']);
    } else if (nm.indexOf('زيت زيتون') !== -1){
      main = findMain(['كبدة إسكندراني','كبد وقوانص','سلطة','طماطم','خيار','خس','فلفل أخضر','جرجير','فول مدمس','جبنة قريش','جبنة بيضاء','جبنة رودس']);
    }
    if (main && main !== foods[i]){
      foods[i]._pairWith = _efNameOf(main);
      foods[i]._isAddon = true;
      foods[i]._pairGroup = (main.food && main.food.id) || _efNameOf(main);
      foods[i]._addonMaxGrams = (/زيت زيتون/.test(nm) && /كبدة إسكندراني|كبد وقوانص/.test(_efNameOf(main))) ? 15 : 10;
      if (!main._pairAddon) main._pairAddon = nm;
    }
  }
}
// [OWNER-RULE] منع التكديس لما المتدرب مختار وجبتين بس:
// ممنوع نوعين كارب أو نوعين بروتين في نفس الوجبة بلا داعٍ.
// بنسيب الأكبر جرامات ونشيل الزايد ونورّد جراماته للمتبقي (نرفع المية مش الأصناف).
function _efDedupeCategory(meal, cat){
  const foods = (meal && meal.foods) || [];
  if (foods.length < 2) return;
  const group = foods.filter(function(f){ return _efCatOf(f) === cat; });
  if (group.length < 2) return;
  let keep = group[0];
  for (var b = 1; b < group.length; b++){ if ((Number(group[b].grams)||0) > (Number(keep.grams)||0)) keep = group[b]; }
  let extra = 0;
  for (var c = 0; c < group.length; c++){ if (group[c] !== keep) extra += Number(group[c].grams) || 0; }
  meal.foods = foods.filter(function(f){ return _efCatOf(f) !== cat || f === keep; });
  if (extra > 0){
    const cap = _efPortionCap(keep);
    const want = (Number(keep.grams) || 0) + Math.round(extra * 0.6);
    _efSetGrams(keep, want > cap ? cap : want);
  }
}
// منع تكرار النشويات المتشابهة في نفس الوجبة
// المستخدم شاف عيش أبيض وعيش بلدي في فطار واحد ودي غلطة كبيرة
function _efIsBreadLike(name){
  const n = String(name || '');
  return n.indexOf('عيش') !== -1 || n.indexOf('خبز') !== -1 || n.indexOf('توست') !== -1 || n.indexOf('رايس كيك') !== -1;
}
function _efDedupeBread(meal){
  const foods = (meal && meal.foods) || [];
  if (foods.length < 2) return meal;
  const breads = [];
  for (var i = 0; i < foods.length; i++){
    if (_efIsBreadLike(_efNameOf(foods[i]))) breads.push(foods[i]);
  }
  if (breads.length < 2) return meal;
  // الأكبر جرامات هو اللي يفضل
  var keep = breads[0];
  var extra = 0;
  for (var b = 1; b < breads.length; b++){
    if ((Number(breads[b].grams) || 0) > (Number(keep.grams) || 0)) keep = breads[b];
  }
  for (var c = 0; c < breads.length; c++){
    if (breads[c] !== keep) extra += Number(breads[c].grams) || 0;
  }
  meal.foods = foods.filter(function(f){ return !_efIsBreadLike(_efNameOf(f)) || f === keep; });
  // نورد جزء من الجرامات المشيلة للعيش المتبقي في حدود سقفه الواقعي
  if (extra > 0){
    const cap = _efPortionCap(keep);
    const want = (Number(keep.grams) || 0) + extra;
    _efSetGrams(keep, want > cap ? cap : want);
  }
  return meal;
}
function _efRecalcTotals(node){
  const fs = (node && node.foods) || [];
  let cals = 0, pro = 0, carb = 0, fat = 0;
  for (var i = 0; i < fs.length; i++){ const f = fs[i]; cals += Number(f.cals != null ? f.cals : f.calories) || 0; pro += Number(f.pro) || 0; carb += Number(f.carb) || 0; fat += Number(f.fat) || 0; }
  cals = Math.round(cals); pro = Math.round(pro); carb = Math.round(carb); fat = Math.round(fat);
  if (node.totals && typeof node.totals === 'object'){ node.totals.cals = cals; node.totals.pro = pro; node.totals.carb = carb; node.totals.fat = fat; }
  if (node.cals != null) node.cals = cals;
  if (node.calories != null) node.calories = cals;
  if (node.pro != null) node.pro = pro;
  if (node.carb != null) node.carb = carb;
  if (node.fat != null) node.fat = fat;
  return { cals: cals, pro: pro, carb: carb, fat: fat };
}
// ── Pre-workout meal injection (training days) ────────────────────────
// طلب صاحب المشروع: أي حد بيتمرن، يوم التمرين تتضاف له وجبة خفيفة قبل
// التمرين تلقائياً — حتى لو مختار وجبتين أو تلاتة — ومن نفس سعرات اليوم
// مش زيادة عليها. طبقة إغلاق السعرات في _efSanitizePlan بتظبط باقي الوجبات بعدها.
//
// الأساس العلمي: كافيين 3-6 مج/كج قبل التمرين بيحسّن الأداء ويقلل الإحساس
// بالمجهود (ISSN 2021)، وكارب سريع مع دهون قليلة بيدي طاقة من غير تقل معدة.
function _efPreWorkoutMeal(targetCals, variant){
  const C = function(id, nameAr, cat, cal, pro, carb, fat){
    return { id:id, nameAr:nameAr, cat:cat, cal:cal, pro:pro, carb:carb, fat:fat, unit:'جم', mealTypes:['pre'] };
  };
  const coffee = C('coffee_black','قهوة سادة','drink',2,0.1,0.3,0);
  const banana = C('mwz','موز','fruit',89,1.1,23,0.3);
  const apple  = C('tfah','تفاح','fruit',52,0.3,14,0.2);
  const dates  = C('tmr','تمر','fruit',313,2.5,75,0.4);
  const choc   = C('dark_choc','شوكولاتة دارك','snack',598,7.8,46,43);
  const sweetPotato = C('sweet_potato','بطاطا مسلوقة','carb',86,1.6,20,0.1);
  // المرجع النهائي: القهوة لا تظهر منفردة، ومعها مصدر طاقة واحد فقط.
  const month = new Date().getMonth() + 1;
  const sweetPotatoInSeason = month >= 8 || month === 1;
  const combos = [
    [ {f:coffee, g:200}, {f:banana, g:100} ],
    [ {f:coffee, g:200}, {f:apple,  g:100} ],
    [ {f:coffee, g:200}, {f:dates,  g:60}  ],
    [ {f:coffee, g:200}, {f:choc,   g:20}  ]
  ];
  if (sweetPotatoInSeason) combos.push([ {f:coffee, g:200}, {f:sweetPotato, g:150} ]);
  const pick = combos[Math.abs(Number(variant)||0) % combos.length];
  const foods = pick.map(function(p){
    const e = { food:p.f, grams:0, cals:0, pro:0, carb:0, fat:0 };
    _efSetGrams(e, p.g);
    return e;
  });
  const cals = foods.reduce(function(a,b){ return a + (Number(b.cals)||0); }, 0);
  return {
    slotKey: 'pre',
    label: 'قبل التمرين',
    description: 'طاقة سريعة وهضم خفيف قبل التمرين ب 45-60 دقيقة',
    targetCals: Math.round(cals),
    targetMacros: {
      protein: Math.round(foods.reduce(function(a,b){ return a+(Number(b.pro)||0); },0)),
      carbs:   Math.round(foods.reduce(function(a,b){ return a+(Number(b.carb)||0); },0)),
      fat:     Math.round(foods.reduce(function(a,b){ return a+(Number(b.fat)||0); },0)),
      cals:    Math.round(cals)
    },
    // [FIX-PRE-TOTALS] كل وجبة بترجع totals ماعدا دي، فأي حسبة بتجمع
    // totals كانت بتعدّها صفر ويبان نقص في سعرات اليوم.
    totals: {
      cals: Math.round(cals),
      pro: Math.round(foods.reduce(function(a,b){ return a+(Number(b.pro)||0); },0)*10)/10,
      carb: Math.round(foods.reduce(function(a,b){ return a+(Number(b.carb)||0); },0)*10)/10,
      fat: Math.round(foods.reduce(function(a,b){ return a+(Number(b.fat)||0); },0)*10)/10
    },
    foods: foods,
    _autoPreWorkout: true
  };
}
// Insert the pre-workout meal right after breakfast (or first) on training days.
function _efInjectPreWorkout(plan, variant){
  if (!plan || !Array.isArray(plan.meals) || !plan.meals.length) return plan;
  for (var i = 0; i < plan.meals.length; i++){
    const sk = String(plan.meals[i] && plan.meals[i].slotKey || '');
    if (sk === 'pre') return plan;   // موجودة فعلاً
  }
  const meal = _efPreWorkoutMeal(Number(plan.targetCals) || 0, variant);
  var at = 0;
  for (var j = 0; j < plan.meals.length; j++){
    if (String(plan.meals[j].slotKey || '') === 'breakfast'){ at = j + 1; break; }
  }
  plan.meals.splice(at, 0, meal);
  plan.hasAutoPreWorkout = true;
  return plan;
}
// [OWNER-RULE][ORDER] ترتيب عرض عناصر الوجبة زي ما طلب صاحب المشروع:
// 1) البروتين  2) الخضار/السلاطة (السلطة النية قبل الخضار المطبوخ)
// 3) الكربوهيدرات  4) الإضافات المرتبطة (زيت/زبدة).
// ترتيب عرض فقط — الإجماليات والحسابات مستقلة عن ترتيب المصفوفة.
var _EF_SALAD_WORDS = ['خس','طماطم','خيار','فلفل','جزر','بصل','جرجير','فجل','كابوتشا','سلطة','خضار مشكل','كرنب'];
function _efIsSaladName(name){
  var n = String(name || '');
  for (var i = 0; i < _EF_SALAD_WORDS.length; i++){ if (n.indexOf(_EF_SALAD_WORDS[i]) !== -1) return true; }
  return false;
}
function _efOrderRank(f){
  var c = String(_efCatOf(f) || '');
  var isVeg = (c === 'veg' || c === 'veggie' || c === 'vegetable' || c === 'vegetables');
  if (c === 'protein') return 0;
  if (c === 'dairy') return 1;
  if (isVeg) return _efIsSaladName(_efNameOf(f)) ? 2 : 3;
  if (c === 'carb') return 4;
  if (c === 'fruit') return 5;
  if (c === 'fat') return 7;   // الإضافات الدهنية آخر الصف
  return 6;
}
// فرز ثابت: العناصر المتساوية في الرتبة تفضل بترتيبها الأصلي.
function _efOrderMealFoods(meal){
  var foods = (meal && meal.foods) || [];
  if (foods.length < 2) return;
  var idx = foods.map(function(f, i){ return { f: f, i: i, r: _efOrderRank(f) }; });
  idx.sort(function(a, b){ return a.r === b.r ? a.i - b.i : a.r - b.r; });
  meal.foods = idx.map(function(x){ return x.f; });
}
// [FIX-R2 #3] العشاء يكرّر عناصر الفطار أو الغداء بكمية أخف — نفس قاعدة
// 25_owner_rules_post.js (RULE-3) بس متطبّقة على شكل الخطة الحقيقي (foods/slotKey).
function _efMirrorDinner(plan){
  var meals = (plan && plan.meals) || [];
  var bf=null, ln=null, dn=null;
  for (var i=0;i<meals.length;i++){
    if (meals[i] && meals[i]._autoPreWorkout) continue;
    var sk=String((meals[i] && meals[i].slotKey)||'');
    if (sk==='lunch') ln=meals[i];
    else if (sk==='dinner') dn=meals[i];
    else if (sk==='breakfast' || _efIsBreakfast(meals[i])) bf=meals[i];
  }
  if (!dn || !Array.isArray(dn.foods) || !dn.foods.length) return;
  if (dn._lightFruitYogurt) return;
  var src = (ln && Array.isArray(ln.foods) && ln.foods.length>=2) ? ln : bf;
  if (!src || !Array.isArray(src.foods) || !src.foods.length || src===dn) return;
  var srcIds = src.foods.map(function(x){ return (x.food&&x.food.id)||''; });
  var dnIds  = dn.foods.map(function(x){ return (x.food&&x.food.id)||''; });
  var hasNew = dnIds.some(function(id){ return id && srcIds.indexOf(id)<0; });
  if (!hasNew) return; // العشاء أصلاً متكرر من وجبة أساسية — سيبه زي ما هو
  var dnTarget = Number(dn.targetCals) || (dn.totals && dn.totals.cals) || 0;
  var srcCals = src.foods.reduce(function(s,f){ return s+(Number(f.cals!=null?f.cals:f.calories)||0); },0);
  var scale = srcCals>0 ? (dnTarget>0 ? dnTarget/srcCals : 0.7) : 0.7;
  if (scale>0.85) scale=0.85; if (scale<0.45) scale=0.45; // العشاء دايماً أخف من المصدر
  var newFoods = [];
  for (var k=0;k<src.foods.length;k++){
    var f=src.foods[k]; var c=_efCatOf(f); var nm=_efNameOf(f);
    if (c==='fruit' || c==='nut' || c==='snack' || nm.indexOf('تمر')!==-1) continue;
    var base=f.food||null;
    var g=Math.round((Number(f.grams)||100)*scale/5)*5; if (g<30) g=30;
    var e={ food:base, grams:0, cals:0, pro:0, carb:0, fat:0 };
    if (base){ _efSetGrams(e, g); }
    else { e.grams=g; e.cals=Math.round((Number(f.cals)||0)*scale); e.pro=f.pro; e.carb=f.carb; e.fat=f.fat; }
    newFoods.push(e);
  }
  if (newFoods.length){ dn.foods = newFoods; dn._mirroredFrom = (src===ln?'lunch':'breakfast'); }
}
// [FIX-R2 #4/#5] الوجبة الرئيسية (خصوصاً الفطار) ما تتبنيش على عنصر خضار واحد
// منفرد زي الطماطم — نكمّله طبق سلطة بإضافة مكوّن تاني عشان العرض يجمعهم "سلطة (…)"
// حسب قاعدة طبق السلطة الموجودة. مااخترعناش قاعدة — بنطبّق الموجود.
function _efFixLoneBreakfastVeg(plan){
  var meals=(plan&&plan.meals)||[];
  var VEG={ khyar:{id:'khyar',nameAr:'خيار',cat:'veggie',cal:16,pro:0.7,carb:3.6,fat:0.1},
           tmatm:{id:'tmatm',nameAr:'طماطم',cat:'veggie',cal:18,pro:0.9,carb:3.9,fat:0.2} };
  for (var m=0;m<meals.length;m++){
    var meal=meals[m];
    if (!meal || meal._autoPreWorkout || !Array.isArray(meal.foods)) continue;
    var slot=String(meal.slotKey||'');
    var main=(slot==='breakfast'||slot==='lunch'||slot==='dinner'||_efIsBreakfast(meal));
    if (!main) continue;
    var saladVegs=meal.foods.filter(function(f){ var c=_efCatOf(f); var isVeg=(c==='veg'||c==='veggie'||c==='vegetable'||c==='vegetables'); return isVeg && _efIsSaladName(_efNameOf(f)); });
    if (saladVegs.length!==1) continue;
    var lone=saladVegs[0]; var lname=_efNameOf(lone);
    if (lname.indexOf('سلطة')!==-1) continue;
    var addBase = lname.indexOf('طماطم')!==-1 ? VEG.khyar : VEG.tmatm;
    if (meal.foods.some(function(f){ return ((f.food&&f.food.id)||'')===addBase.id; })) continue;
    var e={ food:Object.assign({unit:'جم',mealTypes:[]},addBase), grams:0, cals:0, pro:0, carb:0, fat:0 };
    _efSetGrams(e, Math.max(40, Number(lone.grams)||60));
    meal.foods.push(e);
  }
}
// [FIX-SALAD-3] قاعدة طبق السلطة: 3 مكونات مش اتنين، وشكل واحد ثابت
// لليوم كله (مش عناصر مختلفة في كل وجبة). الطبق Dish فيه Ingredients،
// والمتدرب يقدر يشيل أو يزوّد مكوّن من غير ما الطبق نفسه يتشال.
var _EF_SALAD_VEG = {
  tmatm: { id:'tmatm', nameAr:'طماطم',    cat:'veggie', cal:18, pro:0.9, carb:3.9, fat:0.2, g:70 },
  khyar: { id:'khyar', nameAr:'خيار',      cat:'veggie', cal:16, pro:0.7, carb:3.6, fat:0.1, g:60 },
  flfl:  { id:'flfl',  nameAr:'فلفل أخضر',  cat:'veggie', cal:20, pro:0.9, carb:4.6, fat:0.2, g:50 },
  bsl:   { id:'bsl',   nameAr:'بصل',        cat:'veggie', cal:40, pro:1.1, carb:9.0, fat:0.1, g:40 },
  jzr:   { id:'jzr',   nameAr:'جزر',         cat:'veggie', cal:41, pro:0.9, carb:10, fat:0.2, g:50 },
  khs:   { id:'khs',   nameAr:'خس',          cat:'veggie', cal:15, pro:1.2, carb:2.9, fat:0.2, g:60 },
  jrjyr: { id:'jrjyr', nameAr:'جرجير',     cat:'veggie', cal:25, pro:2.6, carb:3.7, fat:0.7, g:50 }
};
// أشكال السلطة المعتمدة (كلها طماطم + خيار + مكوّن تالث).
var _EF_SALAD_FORMS = [
  ['tmatm','khyar','flfl'],
  ['tmatm','khyar','jzr'],
  ['tmatm','khyar','khs'],
  ['tmatm','khyar','jrjyr']
];
function _efSaladForm(plan){
  var v = Number(plan && plan._saladVariant);
  if (!isFinite(v)) v = new Date().getDay();
  var i = ((Math.round(v) % _EF_SALAD_FORMS.length) + _EF_SALAD_FORMS.length) % _EF_SALAD_FORMS.length;
  return _EF_SALAD_FORMS[i];
}
function _efIsVegEntry(f){
  var c = String(_efCatOf(f) || '');
  return (c === 'veg' || c === 'veggie' || c === 'vegetable' || c === 'vegetables' || c === 'salad_veg');
}
function _efSaladIngredients(meal){
  var foods = (meal && meal.foods) || [];
  return foods.filter(function(f){ return _efIsVegEntry(f) && _efIsSaladName(_efNameOf(f)); });
}
function _efEnsureSaladPlate(plan){
  var meals = (plan && plan.meals) || [];
  var form = _efSaladForm(plan);
  plan._saladForm = form.map(function(k){ return _EF_SALAD_VEG[k].nameAr; });
  for (var m = 0; m < meals.length; m++){
    var meal = meals[m];
    if (!meal || meal._autoPreWorkout || !Array.isArray(meal.foods)) continue;
    var slot = String(meal.slotKey || '');
    var main = (slot === 'breakfast' || slot === 'lunch' || slot === 'dinner' || _efIsBreakfast(meal));
    if (!main) continue;
    var have = _efSaladIngredients(meal);
    if (!have.length) continue;              // وجبة مفيهاش سلطة أصلاً — مانفرضهاش
    // لو جاي من المحرك باسم مجمّع (سلطة جاهزة) سيبه زي ما هو.
    var lumped = have.some(function(f){ return _efNameOf(f).indexOf('سلطة') !== -1; });
    if (lumped) continue;
    var ids = meal.foods.map(function(f){ return (f.food && f.food.id) || ''; });
    var guard = 0;
    while (_efSaladIngredients(meal).length < 3 && guard++ < 6){
      var added = false;
      for (var k = 0; k < form.length; k++){
        var base = _EF_SALAD_VEG[form[k]];
        if (!base || ids.indexOf(base.id) !== -1) continue;
        var e = { food: Object.assign({ unit:'جم', mealTypes:[] }, base), grams:0, cals:0, pro:0, carb:0, fat:0 };
        _efSetGrams(e, base.g);
        meal.foods.push(e);
        ids.push(base.id);
        added = true;
        break;
      }
      if (!added) break;
    }
  }
}
// [FIX-BREAD-1] الأكل المتوازن مامعناهوش شيل الخبز: أي وجبة رئيسية فيها
// بروتين لازم يكون معاها مصدر نشويات حقيقي (عيش أسمر/أبيض/رايس كيكس/بطاطس)
// محسوب جوّا سعرات وكربوهيدرات اليوم — مش نزود فول بدل العيش.
var _EF_CARB_OPTS = {
  brown:  { id:'ayshasmr',     nameAr:'عيش أسمر',   cat:'carb', cal:247, pro:9.0, carb:48, fat:2.0, g:60 },
  white:  { id:'ayshbldy',     nameAr:'عيش بلدي',   cat:'carb', cal:265, pro:8.5, carb:55, fat:1.5, g:60 },
  rcakes: { id:'rayskyks',     nameAr:'رايس كيكس', cat:'carb', cal:387, pro:8.2, carb:82, fat:2.8, g:25 },
  potato: { id:'btatsmslwqh',  nameAr:'بطاطس مسلوقة', cat:'carb', cal:87, pro:1.9, carb:20, fat:0.1, g:150 }
};
function _efMealHasCat(meal, cat){
  var foods = (meal && meal.foods) || [];
  for (var i = 0; i < foods.length; i++){ if (_efCatOf(foods[i]) === cat) return true; }
  return false;
}
function _efBannedName(plan, name){
  var bans = (plan && plan._bannedFoodNames) || null;
  if (!Array.isArray(bans)) return false;
  var n = String(name || '');
  for (var i = 0; i < bans.length; i++){ if (bans[i] && n.indexOf(bans[i]) !== -1) return true; }
  return false;
}
// [FIX-BREAD-2] الأنظمة اللي فيها خبز/نشويات أصلاً. كيتو/لوكارب/كارنيفور
// ماينفعش معاهم عيش — ومابنلمسهمش خالص.
var _EF_BREAD_DIETS = ['balanced', 'mediterranean', 'carbcycle', ''];
function _efBreadOk(plan){
  var d = String((plan && plan._dietKey) || 'balanced').toLowerCase();
  return _EF_BREAD_DIETS.indexOf(d) > -1;
}
/* ===== EF OWNER RULES V3 (real foods[] shape) ===== */
function _efCatalogV3(){ try { return (ctx().__EF_FOOD_CATALOG)||[]; } catch(e){ return []; } }
function _efFoodV3(id){ var c=_efCatalogV3(); for(var i=0;i<c.length;i++){ if(c[i] && c[i].id===id) return c[i]; } return null; }
function _efProtCatV3(f){
  if(_efCatOf(f)!=='protein') return null;
  var n=_efNameOf(f);
  if(/(?<![ء-ي])بيض(?![ء-ي])/.test(n)) return null; // egg is NOT an animal-protein source (rule 13): never deduped or counted against the day's single source
  if(/تونة|تونه/.test(n)) return 'tuna';
  if(/سمك|بلطي|بوري|ماكريل|مكريل|سردين|سلمون/.test(n)) return 'fish';
  if(/فراخ|دجاج|صدر|ورك|جناح|بانيه/.test(n)) return 'chicken';
  if(/كبد|كبدة|قوانص/.test(n)) return 'liver';
  if(/لحم|لحمه|بقري|كفتة|كفته|كباب|بفتيك|ريش|شرائح|اسكندران|إسكندران/.test(n)) return 'meat';
  return 'other';
}
function _efIsCookedVegV3(f){ var n=_efNameOf(f),c=_efCatOf(f); return c==='cooked_veg'||/خضار مطبوخ|خضار سوتيه|سوتيه|بامية|باميه|ملوخية|ملوخيه|كوسة|كوسه|باذنجان|سبانخ|قرنبيط|بروكلي|فاصوليا خضراء|بسلة|بسله/.test(n); }
function _efIsSoupV3(f){ var n=_efNameOf(f),c=_efCatOf(f); return c==='soup'||/عدس|شوربة|شوربه/.test(n); }
function _efHasSaladV3(meal){ return (meal.foods||[]).some(function(f){ var n=_efNameOf(f); return /سلطة|سلطه|طماطم|خيار|خس|جرجير|جزر مبشور/.test(n); }); }
function _efMealCalsV3(meal){ return (meal.foods||[]).reduce(function(s,f){ return s+(Number(f.cals!=null?f.cals:f.calories)||0); },0); }
function _efRebuildFromBfV3(meal, bf){
  if(!bf||!Array.isArray(bf.foods)||!bf.foods.length) return false;
  var dnTarget=Number(meal.targetCals)|| _efMealCalsV3(meal) || 0;
  var bfCals=_efMealCalsV3(bf);
  var scale= bfCals>0 && dnTarget>0 ? dnTarget/bfCals : 0.8;
  if(scale>0.9) scale=0.9; if(scale<0.5) scale=0.5;
  var nf=[];
  for(var k=0;k<bf.foods.length;k++){ var f=bf.foods[k]; var c=_efCatOf(f);
    if(c==='fruit'||c==='nut'||c==='snack') continue;
    var base=f.food||null; var g=Math.round((Number(f.grams)||100)*scale/5)*5; if(g<20)g=20;
    var e={food:base,grams:0,cals:0,pro:0,carb:0,fat:0};
    if(base){ _efSetGrams(e,g); } else { e.grams=g; e.cals=Math.round((Number(f.cals)||0)*scale); e.pro=f.pro; e.carb=f.carb; e.fat=f.fat; }
    nf.push(e);
  }
  if(nf.length){ meal.foods=nf; meal._rebuiltFromBreakfast=true; return true; }
  return false;
}
function _efOwnerPre(plan){
  var meals=(plan&&plan.meals)||[];
  var diet=String((plan&&(plan._dietKey||plan.diet))||'balanced').toLowerCase();
  for(var m=0;m<meals.length;m++){
    var meal=meals[m]; if(!meal||meal._autoPreWorkout||!Array.isArray(meal.foods)) continue;
    var slot=String(meal.slotKey||''); var isBf=(slot==='breakfast'||_efIsBreakfast(meal));
    var isMain=(isBf||slot==='lunch'||slot==='dinner');
    var isSnack=(slot==='snack'||/سناك|تحلية|snack/i.test(slot+' '+String(meal.label||'')));
    var out=[];
    for(var i=0;i<meal.foods.length;i++){
      var f=meal.foods[i]; var n=_efNameOf(f); var c=_efCatOf(f);
      if(/فاصوليا حمراء/.test(n)){ var wb=_efFoodV3('faswlyabydamtbwkha'); if(wb){ f.food=wb; _efSetGrams(f, Number(f.grams)||120); n=_efNameOf(f); c=_efCatOf(f); } }
      if(/حمص مسلوق|حمص مطبوخ/.test(n)){ continue; }
      if(isMain && /بطاطس مقلية|شيبسي/.test(n)){ var bp=_efFoodV3('btatsmslwqa'); if(bp){ f.food=bp; _efSetGrams(f, Number(f.grams)||150); n=_efNameOf(f); c=_efCatOf(f); } }
      if(/زبادي/.test(n) && /يوناني|لايت|بالفاكهة/.test(n)){ var ny=_efFoodV3('zbadytbyay'); if(ny){ f.food=ny; _efSetGrams(f, Number(f.grams)||100); n=_efNameOf(f); c=_efCatOf(f); } }
      if(isSnack){
        if(_efIsSoupV3(f)) continue;
        if(_efIsCookedVegV3(f)) continue;
        if(c==='protein') continue;
        if(/(?<![ء-ي])بيض(?![ء-ي])/.test(n)) continue;
        if(/جبن|قريش/.test(n)) continue;
        if(/فول مدمس/.test(n)) continue;
        if(/رز|أرز|مكرونة|مكرونه/.test(n)) continue; // no rice/pasta in snacks (any type)
        if(/عيش|توست|رغيف/.test(n)) continue; // no bread/toast in snacks (any type)
        if(/بطاطس|بطاطا/.test(n)) continue; // no potato in snacks
      }
      out.push(f);
    }
    meal.foods=out;
  }
  // [OWNER-RULE] Fish/Tuna pairing: never with potato, cooked veg, or soup. Tuna -> bread, other fish -> rice (bread diets only). Prefer tuna-in-oil (common in Egypt) over water tuna.
  for(var mf=0;mf<meals.length;mf++){
    var mmf=meals[mf]; if(!mmf||mmf._autoPreWorkout||!Array.isArray(mmf.foods)) continue;
    var sf=String(mmf.slotKey||''); if(!(sf==='breakfast'||sf==='lunch'||sf==='dinner'||_efIsBreakfast(mmf))) continue;
    var hasFish=mmf.foods.some(function(f){ return /سمك|بلطي|بوري|ماكريل|مكريل|سردين|سلمون|بلاميط|قاروص|دنيس|تونة|تونه/.test(_efNameOf(f)); });
    if(!hasFish) continue;
    var hasTuna=mmf.foods.some(function(f){ return /تونة|تونه/.test(_efNameOf(f)); });
    for(var tf=0;tf<mmf.foods.length;tf++){ var tn=_efNameOf(mmf.foods[tf]); if(/تونة|تونه/.test(tn) && /مياه|ماء|مية/.test(tn)){ var oilT=_efFoodV3('qta_twna_balzyt'); if(oilT){ mmf.foods[tf].food=oilT; _efSetGrams(mmf.foods[tf], Math.min(200, Number(mmf.foods[tf].grams)||150)); } } }
    var remCal=0;
    mmf.foods=mmf.foods.filter(function(f){ var n=_efNameOf(f); if(/بطاطس|بطاطا/.test(n)){ remCal+=Number(f.cals!=null?f.cals:f.calories)||0; return false; } if(_efIsCookedVegV3(f)){ return false; } if(_efIsSoupV3(f)){ remCal+=Number(f.cals!=null?f.cals:f.calories)||0; return false; } return true; });
    if(_EF_BREAD_DIETS.indexOf(diet)!==-1){
      var hasGrain=mmf.foods.some(function(f){ var n=_efNameOf(f); return /عيش|رز|أرز|توست|مكرونة|مكرونه|رايس كيك/.test(n); });
      if(!hasGrain){ var carbId=hasTuna?'ayshbldy':'arzabydmtbwkh'; var cff=_efFoodV3(carbId); if(cff){ var gg=remCal>0?Math.round(remCal/((Number(cff.cal)||130))*100):(hasTuna?90:150); var capg=_efPortionCap({food:cff}); gg=Math.min(capg,Math.max(50,gg)); var cee={food:cff,grams:0,cals:0,pro:0,carb:0,fat:0}; _efSetGrams(cee,gg); mmf.foods.push(cee); } }
    }
  }
  // الشوربة مسموحة مع الوجبة والكارب؛ المنع الوحيد مع السمك والتونة.
  for(var m3=0;m3<meals.length;m3++){
    var meal3=meals[m3]; if(!meal3||meal3._autoPreWorkout||!Array.isArray(meal3.foods)) continue;
    var prot=[]; for(var i3=0;i3<meal3.foods.length;i3++){ var pc=_efProtCatV3(meal3.foods[i3]); if(pc) prot.push({f:meal3.foods[i3],g:Number(meal3.foods[i3].grams)||0}); }
    if(prot.length>1){ var keep=prot[0]; for(var k3=1;k3<prot.length;k3++){ if(prot[k3].g>keep.g) keep=prot[k3]; } meal3.foods=meal3.foods.filter(function(f){ return !_efProtCatV3(f) || f===keep.f; }); }
  }
  for(var m4=0;m4<meals.length;m4++){
    var meal4=meals[m4]; if(!meal4||meal4._autoPreWorkout||!Array.isArray(meal4.foods)) continue;
    if(String(meal4.slotKey||'')==='breakfast'||_efIsBreakfast(meal4)) continue;
    var hasHeavy=meal4.foods.some(function(f){ return _efProtCatV3(f); });
    var hasCV=meal4.foods.some(_efIsCookedVegV3);
    if(hasHeavy||hasCV){ meal4.foods=meal4.foods.filter(function(f){ return !/زبادي/.test(_efNameOf(f)); }); }
  }
  if(diet==='balanced'){
    for(var m5=0;m5<meals.length;m5++){
      var meal5=meals[m5]; if(!meal5||meal5._autoPreWorkout||!Array.isArray(meal5.foods)) continue;
      if(!(String(meal5.slotKey||'')==='breakfast'||_efIsBreakfast(meal5))) continue;
      var cnt=meal5.foods.filter(function(f){ var n=_efNameOf(f); var c=_efCatOf(f); return c==='protein'||c==='dairy'||/فول مدمس|(?<![ء-ي])بيض(?![ء-ي])|جبن|قريش/.test(n); }).length;
      if(cnt>=2) continue;
      var q=_efFoodV3('jbnaqrysh'); if(q && !meal5.foods.some(function(f){ return ((f.food&&f.food.id)||'')==='jbnaqrysh'; })){ var e={food:q,grams:0,cals:0,pro:0,carb:0,fat:0}; _efSetGrams(e,90); meal5.foods.push(e); }
    }
  }
}
function _efOwnerPost(plan){
  var meals=(plan&&plan.meals)||[];
  // العشاء الخفيف الذي اختاره المحرك يظل زبادي طبيعي + فاكهة فقط.
  // طبقات موازنة السعرات السابقة قد تضيف بروتينا ثقيلا؛ ننظفه هنا قبل
  // آخر تطبيق للحدود اليومية، من غير ما نلمس باقي أنواع العشاء.
  for(var ld=0;ld<meals.length;ld++){
    var ldm=meals[ld]; if(!ldm||!ldm._lightFruitYogurt||!Array.isArray(ldm.foods)) continue;
    ldm.foods=ldm.foods.filter(function(f){
      var cat=_efCatOf(f), name=_efNameOf(f);
      return cat==='fruit' || /زبادي/.test(name);
    });
  }
  for(var m=0;m<meals.length;m++){
    var meal=meals[m]; if(!meal||!Array.isArray(meal.foods)) continue;
    var hasTahini=meal.foods.some(function(f){ return /طحينة|طحينه/.test(_efNameOf(f)); });
    var hasOlive=meal.foods.some(function(f){ var n=_efNameOf(f); return /زيتون/.test(n) && !/زيت زيتون/.test(n); });
    if(hasTahini&&hasOlive){ meal.foods=meal.foods.filter(function(f){ var n=_efNameOf(f); return !(/زيتون/.test(n) && !/زيت زيتون/.test(n)); }); }
    // Clarification: the "no oil/butter without salad" rule applies ONLY to meals that contain an ANIMAL protein (chicken/meat/fish/tuna/liver). Cheese/fool/fried-egg meals keep their own fat rules.
    var _hasAnimalProt=meal.foods.some(function(f){ return _efProtCatV3(f); });
    if(_hasAnimalProt && !_efHasSaladV3(meal)){ meal.foods=meal.foods.filter(function(f){ var n=_efNameOf(f); if(/زيت زيتون/.test(n)) return false; if(/زبدة|زبده|سمنة|سمنه/.test(n)) return false; return true; }); }
  }
  // Auto plans use NORMAL natural yogurt only. Greek/light/fruit yogurts stay in the DB with their own calories, but are swapped to normal here so generated plans never show them.
  for(var yz=0;yz<meals.length;yz++){ var mz=meals[yz]; if(!mz||!Array.isArray(mz.foods)) continue; for(var fz=0;fz<mz.foods.length;fz++){ var yf=mz.foods[fz]; var yn=_efNameOf(yf); if(/زبادي/.test(yn) && /يوناني|لايت|بالفاكهة/.test(yn)){ var nyg=_efFoodV3('zbadytbyay'); if(nyg){ yf.food=nyg; _efSetGrams(yf, Math.min(150, Number(yf.grams)||150)); } } } }
  // R1: balanced breakfast must keep a grain carb + at least two proteins. Enforced here (last pass) so earlier rebalance passes can't strip the additions.
  var _dkP=String((plan&&(plan._dietKey||plan.diet))||'').toLowerCase();
  if(_dkP==='balanced'){
    for(var bi=0;bi<meals.length;bi++){ var bm=meals[bi]; if(!bm||bm._autoPreWorkout||!Array.isArray(bm.foods)) continue; if(!(String(bm.slotKey||'')==='breakfast'||_efIsBreakfast(bm))) continue;
      var hasGrain=bm.foods.some(function(f){ var n=_efNameOf(f); return /عيش|رايس كيك|rice cake|بطاطس|بطاطا|توست|شوفان/.test(n); });
      if(!hasGrain){ var eb=_efFoodV3('ayshbldy'); if(eb){ var ee={food:eb,grams:0,cals:0,pro:0,carb:0,fat:0}; _efSetGrams(ee,65); bm.foods.push(ee); } }
      var pcnt=bm.foods.filter(function(f){ var n=_efNameOf(f); var c=_efCatOf(f); return c==='protein'||c==='dairy'||/فول مدمس|(?<![ء-ي])بيض(?![ء-ي])|جبن|قريش/.test(n); }).length;
      var _q1=_efFoodV3('jbnaqrysh'); var _hasQ=bm.foods.some(function(f){ return ((f.food&&f.food.id)||'')==='jbnaqrysh'; });
      if(pcnt<2){ if(_q1 && !_hasQ){ var qe={food:_q1,grams:0,cals:0,pro:0,carb:0,fat:0}; _efSetGrams(qe,90); bm.foods.push(qe); } }
      break;
    }
  }
  // Clarification: egg must NOT appear in the same meal as tuna. Drop egg from any tuna meal (egg is still allowed in other meals that day).
  for(var et=0;et<meals.length;et++){ var em=meals[et]; if(!em||!Array.isArray(em.foods)) continue; var hasT=em.foods.some(function(f){ return /تونة|تونه/.test(_efNameOf(f)); }); if(hasT){ em.foods=em.foods.filter(function(f){ return !/(?<![ء-ي])بيض(?![ء-ي])/.test(_efNameOf(f)); }); } }
  // Safety net: snacks never contain rice/bread/potato/pasta/protein/cheese/egg/fool/soup/cooked-veg (in case rebalance added a carb after Pre cleaned the snack).
  for(var scn=0;scn<meals.length;scn++){ var smn=meals[scn]; if(!smn||!Array.isArray(smn.foods)) continue; var ssl=String(smn.slotKey||''); if(!(ssl==='snack'||/سناك|تحلية|snack/i.test(ssl+' '+String(smn.label||'')))) continue; smn.foods=smn.foods.filter(function(f){ var n=_efNameOf(f); if(_efIsSoupV3(f)||_efIsCookedVegV3(f)) return false; if(_efCatOf(f)==='protein') return false; if(/(?<![ء-ي])بيض(?![ء-ي])/.test(n)) return false; if(/جبن|قريش/.test(n)) return false; if(/فول مدمس/.test(n)) return false; if(/رز|أرز|مكرونة|مكرونه/.test(n)) return false; if(/عيش|توست|رغيف/.test(n)) return false; if(/بطاطس|بطاطا/.test(n)) return false; return true; }); }
  var mains=meals.filter(function(mm){ if(!mm||mm._autoPreWorkout) return false; var s=String(mm.slotKey||''); return s==='breakfast'||s==='lunch'||s==='dinner'||_efIsBreakfast(mm); });
  var bf=null, ln=null;
  for(var a=0;a<mains.length;a++){ var s=String(mains[a].slotKey||''); if(!bf && (s==='breakfast'||_efIsBreakfast(mains[a]))) bf=mains[a]; if(!ln && s==='lunch') ln=mains[a]; }
  var tunaMeals=mains.filter(function(mm){ return (mm.foods||[]).some(function(f){ return /تونة|تونه/.test(_efNameOf(f)); }); });
  if(tunaMeals.length>1){
    var primary=(ln && tunaMeals.indexOf(ln)>=0)? ln : tunaMeals[0];
    for(var t=0;t<tunaMeals.length;t++){ if(tunaMeals[t]!==primary){ if(!_efRebuildFromBfV3(tunaMeals[t], bf)){ tunaMeals[t].foods=tunaMeals[t].foods.filter(function(f){ return !/تونة|تونه/.test(_efNameOf(f)); }); } } }
  }
  var tEntries=[]; for(var mm=0;mm<mains.length;mm++){ (mains[mm].foods||[]).forEach(function(f){ if(/تونة|تونه/.test(_efNameOf(f))) tEntries.push(f); }); }
  var tTot=tEntries.reduce(function(s,f){ return s+(Number(f.grams)||0); },0);
  if(tTot>300 && tTot>0){ var sc=300/tTot; tEntries.forEach(function(f){ _efSetGrams(f, Math.max(20, Math.round((Number(f.grams)||0)*sc))); }); }
  var dayCat=null, dayProtFood=null; if(ln){ (ln.foods||[]).some(function(f){ var pc=_efProtCatV3(f); if(pc){ dayCat=pc; dayProtFood=f.food; return true; } return false; }); }
  if(dayCat && bf){ bf.foods=bf.foods.filter(function(f){ var pc=_efProtCatV3(f); return !pc || pc===dayCat; }); }
  // Rule 13: whole day = ONE animal-protein source (egg excluded). Any OTHER main meal carrying a different animal source is switched to the day's source, keeping its grams.
  if(dayCat && dayProtFood){ for(var dm=0;dm<mains.length;dm++){ var mmd=mains[dm]; if(mmd===ln||!Array.isArray(mmd.foods)) continue; for(var fi2=0;fi2<mmd.foods.length;fi2++){ var pc2=_efProtCatV3(mmd.foods[fi2]); if(pc2 && pc2!==dayCat){ var gk2=Number(mmd.foods[fi2].grams)||150; mmd.foods[fi2].food=dayProtFood; _efSetGrams(mmd.foods[fi2], gk2); } } } }
  var yEntries=[]; for(var mm2=0;mm2<meals.length;mm2++){ var meal2=meals[mm2]; if(!meal2||!Array.isArray(meal2.foods)) continue; meal2.foods.forEach(function(f){ if(/زبادي/.test(_efNameOf(f))) yEntries.push({f:f,meal:meal2}); }); }
  var yTot=yEntries.reduce(function(s,o){ return s+(Number(o.f.grams)||0); },0);
  if(yTot>200 && yEntries.length){
    var keepY=null;
    for(var yl=0;yl<yEntries.length;yl++){ if(yEntries[yl].meal._lightFruitYogurt){ keepY=yEntries[yl]; break; } }
    for(var y=0;!keepY&&y<yEntries.length;y++){ var s=String(yEntries[y].meal.slotKey||''); if(s==='breakfast'||_efIsBreakfast(yEntries[y].meal)){ keepY=yEntries[y]; break; } }
    if(!keepY) keepY=yEntries[0];
    for(var y2=0;y2<yEntries.length;y2++){ if(yEntries[y2]!==keepY){ var mo=yEntries[y2].meal, fo=yEntries[y2].f; mo.foods=mo.foods.filter(function(x){ return x!==fo; }); } }
    _efSetGrams(keepY.f, 200);
  }
}

function _efEnsureMainCarb(plan){
  if (!_efBreadOk(plan)) return;      // نظام قليل النشويات — مفيش عيش
  var meals = (plan && plan.meals) || [];
  for (var m = 0; m < meals.length; m++){
    var meal = meals[m];
    if (!meal || meal._autoPreWorkout || !Array.isArray(meal.foods)) continue;
    var slot = String(meal.slotKey || '');
    var isBf = (slot === 'breakfast' || _efIsBreakfast(meal));
    // العيش عادة فطار مصرية بس: الغدا/العشا سايبين للمحرك زي ما همّا.
    if (!isBf) continue;
    if (!_efMealHasCat(meal, 'protein') && !_efMealHasCat(meal, 'dairy')) continue;
    if (_efMealHasCat(meal, 'carb')) continue;                      // فيها نشويات خلاص
    var order = ['brown','white','rcakes','potato'];
    for (var o = 0; o < order.length; o++){
      var base = _EF_CARB_OPTS[order[o]];
      if (!base) continue;
      if (_efBannedName(plan, base.nameAr)) continue;
      if (meal.foods.some(function(f){ return ((f.food && f.food.id) || '') === base.id; })) continue;
      var e = { food: Object.assign({ unit:'جم', mealTypes:[] }, base), grams:0, cals:0, pro:0, carb:0, fat:0 };
      var names = meal.foods.map(_efNameOf).concat(base.nameAr);
      if (!_efPairingKeep(e, names, meal)) continue;
      var cap = _efPortionCap(e);
      var g = Math.min(cap, base.g);
      if (g < 15) continue;
      _efSetGrams(e, Math.round(g / 5) * 5);
      meal.foods.push(e);
      meal._breadRestored = base.nameAr;
      break;
    }
  }
}
// ===== [OWNER-RULE nutrition v2] added-fat sizing + day balance =====
function _efMealCals(m){ var fs=(m&&m.foods)||[]; var s=0; for(var i=0;i<fs.length;i++){ s+=Number(fs[i].cals!=null?fs[i].cals:fs[i].calories)||0; } return s; }
function _efIsVegF(f){ var c=_efCatOf(f); return c==='veg'||c==='veggie'||c==='vegetable'||c==='vegetables'||c==='salad_veg'; }
function _efIsAddedFat(f){ var n=_efNameOf(f); if(n.indexOf('فول سوداني')!==-1) return false; if(n.indexOf('تونة')!==-1||n.indexOf('تونه')!==-1) return false; if(n.indexOf('زيتون')!==-1&&n.indexOf('زيت زيتون')===-1)return false; return n.indexOf('زيت زيتون')!==-1 || n.indexOf('زبدة')!==-1 || n.indexOf('سمنة')!==-1; }
function _efSetGramsFine(f,g){ g=Math.max(0,Math.round(g)); var base=f.food||null; f.grams=g; var R1=function(x){return Math.round(x*10)/10;}; if(base&&base.cal!=null){ f.cals=Math.round((Number(base.cal)||0)*g/100); if(base.pro!=null)f.pro=R1((Number(base.pro)||0)*g/100); if(base.carb!=null)f.carb=R1((Number(base.carb)||0)*g/100); if(base.fat!=null)f.fat=R1((Number(base.fat)||0)*g/100);} if(f.calories!=null)f.calories=f.cals; }
function _efSnapFat(g,max){ g=Math.round(Number(g)||0); return g<2?0:Math.min(max||10,g); }
// الزيت/الزبدة اختياريان: يكملان احتياج الدهون فقط بكمية صحيحة من 2 إلى 10 جم.
function _efEnforceFatPairing(plan){
  var meals=(plan&&plan.meals)||[];
  for(var pm=0; pm<meals.length; pm++){
    var pmeal=meals[pm]; if(!pmeal||!Array.isArray(pmeal.foods)) continue;
    var _names=pmeal.foods.map(_efNameOf);
    var _oilOk=_names.some(function(n){ return /سلطة/.test(n) || (/فول/.test(n)&&!/سوداني/.test(n)) || (/جبن/.test(n)&&/بيضا|بيضاء|قريش|رودس/.test(n)) || /كبدة إسكندراني|كبد وقوانص/.test(n); });
    var _butterOk=_names.some(function(n){ return (/فول/.test(n)&&!/سوداني/.test(n)) || (/بيض/.test(n)&&/مقلي/.test(n)); });
    var _seenOil=false;
    pmeal.foods=pmeal.foods.filter(function(f){
      var n=_efNameOf(f);
      if(/زيت زيتون/.test(n)){ if(!_oilOk||_seenOil) return false; _seenOil=true; return true; }
      if(/زبدة|زبده|سمنة|سمنه/.test(n)){ if(!_butterOk) return false; return true; }
      return true;
    });
    if(typeof _efRecalcTotals==="function") _efRecalcTotals(pmeal);
  }
}

function _efSizeAddedFats(plan){
  var meals=(plan&&plan.meals)||[]; var tgtFat=(plan.targetMacros&&Number(plan.targetMacros.fat))||0;
  var baseFat=0, added=[];
  for(var m=0;m<meals.length;m++){
    var fs=(meals[m]&&meals[m].foods)||[];
    for(var i=0;i<fs.length;i++){
      var f=fs[i];
      if(_efIsAddedFat(f)){ var _mn=(meals[m].foods||[]).map(_efNameOf).join(' '); f._addonMaxGrams=(/زيت زيتون/.test(_efNameOf(f))&&/كبدة إسكندراني|كبد وقوانص/.test(_mn))?15:_efAddedFatItemMax(plan); added.push({meal:meals[m],f:f}); }
      else baseFat+=Number(f.fat)||0;
    }
  }
  if(!added.length) return;
  var gap=Math.max(0,tgtFat-baseFat);
  for(var a=0;a<added.length;a++){
    var item=added[a], f=item.f;
    var perFat=(f.food&&f.food.fat!=null)?Number(f.food.fat):100;
    var perCal=(f.food&&f.food.cal!=null)?Number(f.food.cal):884;
    var mealTarget=Number(item.meal.targetCals)||0;
    var without=_efMealCals(item.meal)-(Number(f.cals)||0);
    var calorieNeed=mealTarget>0?Math.max(0,mealTarget-without)/(perCal/100):0;
    var remaining=added.length-a;
    var fatNeed=perFat>0?(gap/remaining)/(perFat/100):0;
    // الكمية ناتجة من فجوة الوجبة وفجوة دهون اليوم، وليست اختيار 5/10 ثابت.
    var need=Math.min(calorieNeed||10,fatNeed||calorieNeed||0);
    var g=_efSnapFat(need,_efAddedFatItemMax(plan));
    if(g<=0){ item.meal.foods=item.meal.foods.filter(function(x){return x!==f;}); continue; }
    _efSetGramsFine(f,Math.min(Number(f._addonMaxGrams)||10,g));
    gap=Math.max(0,gap-(Number(f.fat)||0));
  }
  for(var r=0;r<meals.length;r++) _efRecalcTotals(meals[r]);
}
function _efReducibleFoods(meal){ var fs=(meal&&meal.foods)||[],out=[],pc=0; for(var i=0;i<fs.length;i++){ if(_efCatOf(fs[i])==='protein')pc++; } for(var j=0;j<fs.length;j++){ var f=fs[j]; if(_efIsVegF(f))continue; var per=(f.food&&f.food.cal!=null)?Number(f.food.cal):0; if(!per)continue; if((Number(f.grams)||0)<=20)continue; if(_efCatOf(f)==='protein'&&pc<=1)continue; out.push(f);} return out; }
function _efGrowableFoods(meal){ var fs=(meal&&meal.foods)||[],out=[]; for(var i=0;i<fs.length;i++){ var f=fs[i]; if(_efIsVegF(f))continue; if(_efIsAddedFat(f))continue; if(_efDailyGroup(f))continue; var per=(f.food&&f.food.cal!=null)?Number(f.food.cal):0; if(!per)continue; var cap=_efPortionCap(f); if((Number(f.grams)||0)<cap-2)out.push(f);} return out; }
// [OWNER-RULE] توازن اليوم: مفيش وجبة تاخد أكتر من 40% من سعرات اليوم.
// [FIX-HARDCAP] تصغير وجبة بمقدار سعرات معينة (بحماية 20ج وبروتين واحد).
function _efShrinkBy(meal, need){
  var moved=0, guard=0;
  while(moved<need-2 && guard++<60){
    var red=_efReducibleFoods(meal); if(!red.length) break;
    red.sort(function(a,b){ return (Number(b.cals)||0)-(Number(a.cals)||0); });
    var did=false;
    for(var i=0;i<red.length && moved<need-2;i++){
      var f=red[i]; var per=(f.food&&f.food.cal!=null)?Number(f.food.cal):0; if(!per)continue;
      var cur=Number(f.grams)||0; if(cur-5<20)continue;
      var step=Math.round((need-moved)/per*100); step=Math.round(step/5)*5; if(step<5)step=5;
      var maxCut=cur-20; if(step>maxCut)step=Math.floor(maxCut/5)*5; if(step<5)continue;
      var before=Number(f.cals)||0; _efSetGrams(f,cur-step); moved+=before-(Number(f.cals)||0); did=true;
    }
    if(!did) break;
  }
  return moved;
}
// [FIX-HARDCAP] توزيع سعرات منقولة على الوجبات الأخف (تكبير الموجود ثم إضافة نشوية).
function _efDistribute(real, heavy, amount){
  var left=amount;
  var others=real.filter(function(m){ if(m===heavy)return false; var _sk=String(m.slotKey||'')+' '+String(m.label||''); if(/snack|سناك|تحلية|قبل التمرين|بعد التمرين/i.test(_sk))return false; return true; }).sort(function(a,b){ return _efMealCals(a)-_efMealCals(b); });
  for(var o=0;o<others.length && left>2;o++){
    var meal=others[o]; var gf=_efGrowableFoods(meal); gf.sort(function(a,b){ return (Number(a.cals)||0)-(Number(b.cals)||0); });
    for(var g=0;g<gf.length && left>2;g++){
      var f=gf[g]; var per=(f.food&&f.food.cal!=null)?Number(f.food.cal):0; if(!per)continue;
      var cap=_efPortionCap(f); var cur=Number(f.grams)||0; var room=cap-cur; if(room<5)continue;
      var add=Math.round(left/per*100); add=Math.round(add/5)*5; if(add>room)add=Math.floor(room/5)*5; if(add<5)continue;
      var b=Number(f.cals)||0; _efSetGrams(f,cur+add); left-=(Number(f.cals)||0)-b;
    }
  }
  var guard=0;
  while(left>15 && guard++<8){
    var meal2=null, mc=1e12;
    for(var k=0;k<others.length;k++){ var sk=String(others[k].slotKey||'')+' '+String(others[k].label||''); if(/snack|سناك|تحلية/.test(sk))continue; var c=_efMealCals(others[k]); if(c<mc){mc=c;meal2=others[k];} }
    if(!meal2) break;
    var addFood=_efIsBreakfast(meal2)?{id:'ayshasmr',nameAr:'عيش أسمر',cat:'carb',cal:247,pro:9,carb:48,fat:2}:{id:'arzabydmtbwkh',nameAr:'أرز أبيض مطبوخ',cat:'carb',cal:130,pro:2.7,carb:28,fat:0.3};
    var per=addFood.cal, cap3=_efPortionCap({food:addFood});
    var lf=meal2.foods||[], existing=null;
    for(var q=0;q<lf.length;q++){ if(((lf[q].food&&lf[q].food.id)||'')===addFood.id){existing=lf[q];break;} }
    if(existing){ var cur3=Number(existing.grams)||0; var room3=cap3-cur3; if(room3<5)break; var add3=Math.round(left/per*100); add3=Math.round(add3/5)*5; if(add3>room3)add3=Math.floor(room3/5)*5; if(add3<5)break; var b3=Number(existing.cals)||0; _efSetGrams(existing,cur3+add3); left-=(Number(existing.cals)||0)-b3; }
    else { var wg=Math.round(left/per*100); wg=Math.round(wg/5)*5; if(wg>cap3)wg=Math.floor(cap3/5)*5; if(wg<5)break; var entry={food:Object.assign({unit:'جم',mealTypes:[]},addFood),grams:0,cals:0,pro:0,carb:0,fat:0}; _efSetGrams(entry,wg); meal2.foods.push(entry); left-=Number(entry.cals)||0; }
  }
  return amount-left;
}
// [FIX-UNDERTARGET] لو اليوم لسه ناقص بعد إغلاق السعرات، مدّد الأصناف الكثيفة
// (كارب/مكسرات/فاكهة/زبادي) لحد سقف مرن واقعي. مابنمدّدش بيض/لحمة/جبنة فوق السقف.
function _efStretchToTarget(plan){
  var meals=(plan&&plan.meals)||[];
  var tgt=Number(plan.targetCals)||0; if(!tgt) return;
  var stretch={carb:1.5, nut:1.4, fruit:1.3, dairy:1.3};
  var _realN=meals.filter(function(mm){return mm && !mm._autoPreWorkout && ((mm.foods||[]).length>0);}).length;
  // [v2] كل الوجبات بتوصل للهدف عبر تكبير الأساسي، مش بس الوجبتين. // للوجبتين الأولوية لسقف 50%، مش للوصول للهدف.
  function _day(){ var s=0; for(var i=0;i<meals.length;i++){ s+=_efMealCals(meals[i]); } return s; }
  var guard=0;
  while(_day()<tgt*0.95 && guard++<80){
    var moved=false;
    for(var m=0;m<meals.length;m++){
      var meal=meals[m]; if(!meal||meal._autoPreWorkout) continue;
      var fs=meal.foods||[];
      for(var j=0;j<fs.length;j++){
        if(_day()>=tgt*0.95) break;
        var f=fs[j]; var cat=_efCatOf(f);
        var factor=stretch[cat]; if(!factor) continue;
        if(_efDailyGroup(f)) continue;
        if(_efIsVegF(f)) continue;
        var per=(f.food&&f.food.cal!=null)?Number(f.food.cal):0; if(!per)continue;
        var cap=_efPortionCap(f)*factor;
        var cur=Number(f.grams)||0; if(cur>=cap) continue;
        var add=Math.max(5, Math.round((tgt-_day())/per*100)); add=Math.round(add/5)*5;
        if(cur+add>cap) add=Math.floor((cap-cur)/5)*5; if(add<5) continue;
        var before=Number(f.cals)||0; _efSetGrams(f,cur+add); if((Number(f.cals)||0)>before) moved=true;
      }
    }
    if(!moved) break;
  }
}
// [FIX-HARDCAP] فرض سقف نسبة الوجبة بشكل مضمون: وجبتين=50%، 3+ =40%.
// [FIX-HARDCAP v2] فرض سقف نصيب الوجبة: رئيسية 35% (50% لو وجبتين)، سناك <=20%.
function _efHardCapMeals(plan){
  var meals=(plan&&plan.meals)||[];
  for(var pass=0; pass<24; pass++){
    var real=meals.filter(function(m){ return m && !m._autoPreWorkout && ((m.foods||[]).length>0); });
    if(real.length<2) return;
    var day=0; for(var i=0;i<real.length;i++) day+=_efMealCals(real[i]);
    if(day<=0) return;
    var heavy=null, worst=0;
    for(var h=0;h<real.length;h++){
      var lim=_efSlotShareCeil(real[h], real.length)*day;
      var over=_efMealCals(real[h]) - lim;
      if(over>worst){ worst=over; heavy=real[h]; }
    }
    if(!heavy || worst<=5) return;
    var moved = _efShrinkBy(heavy, worst);
    if(moved<=2) return;
    _efDistribute(real, heavy, moved);
    for(var r=0;r<real.length;r++) _efRecalcTotals(real[r]);
  }
}
function _efRebalanceDay(plan){
  var meals=(plan&&plan.meals)||[]; var real=[]; for(var i=0;i<meals.length;i++){ if(!(meals[i]&&meals[i]._autoPreWorkout)) real.push(meals[i]); }
  // [FIX-MEALCAP] وجبتين باليوم: سقف الوجبة 50%. 3 وجبات أو أكتر: سقف 40%.
  if(real.length<2) return;
  var _twoM = real.length <= 2;
  var MAX = _twoM ? 0.50 : 0.35, TARGET = _twoM ? 0.47 : 0.33, guard=0;
  while(guard++<120){
    var day=0; for(var d=0;d<real.length;d++){ day+=_efMealCals(real[d]); } if(day<=0) break;
    var heavy=null,hc=-1; for(var h=0;h<real.length;h++){ var cc=_efMealCals(real[h]); if(cc>hc){hc=cc;heavy=real[h];} }
    if(hc<=day*MAX+2) break;
    var light=null,lc=1e12; for(var l=0;l<real.length;l++){ if(real[l]===heavy)continue; var cl=_efMealCals(real[l]); if(cl<lc){lc=cl;light=real[l];} }
    if(!light) break;
    var want=Math.min(hc-day*TARGET, day*0.05); if(want<15) break;
    var red=_efReducibleFoods(heavy); if(!red.length) break;
    red.sort(function(a,b){ var ra=(_efCatOf(a)==='protein')?1:0, rb=(_efCatOf(b)==='protein')?1:0; if(ra!==rb)return ra-rb; return (Number(b.cals)||0)-(Number(a.cals)||0); });
    var moved=0;
    for(var r=0;r<red.length&&moved<want;r++){ var f=red[r]; var per=(f.food&&f.food.cal!=null)?Number(f.food.cal):0; if(!per)continue; var cur=Number(f.grams)||0; var maxCut=cur-20; if(maxCut<5)continue; var wc=Math.min(maxCut,Math.round((want-moved)/per*100)); wc=Math.round(wc/5)*5; if(wc<5)continue; var before=Number(f.cals)||0; _efSetGrams(f,cur-wc); moved+=before-(Number(f.cals)||0); }
    if(moved<10) break;
    var grew=0, gf=_efGrowableFoods(light); gf.sort(function(a,b){ return (Number(a.cals)||0)-(Number(b.cals)||0); });
    for(var g2=0;g2<gf.length&&grew<moved;g2++){ var f2=gf[g2]; var per2=(f2.food&&f2.food.cal!=null)?Number(f2.food.cal):0; if(!per2)continue; var cap=_efPortionCap(f2); var cur2=Number(f2.grams)||0; var room=cap-cur2; if(room<5)continue; var wa=Math.min(room,Math.round((moved-grew)/per2*100)); wa=Math.round(wa/5)*5; if(wa<5)continue; var b2=Number(f2.cals)||0; _efSetGrams(f2,cur2+wa); grew+=(Number(f2.cals)||0)-b2; }
    if(grew<moved-20){ var deficit=moved-grew; var addFood=_efIsBreakfast(light)?{id:'ayshasmr',nameAr:'عيش أسمر',cat:'carb',cal:247,pro:9,carb:48,fat:2}:{id:'arzabydmtbwkh',nameAr:'أرز أبيض مطبوخ',cat:'carb',cal:130,pro:2.7,carb:28,fat:0.3}; var hasCarb=false; var lf=light.foods||[]; for(var q=0;q<lf.length;q++){ if(_efCatOf(lf[q])==='carb'){hasCarb=true;break;} } var ids=lf.map(function(x){return (x.food&&x.food.id)||'';}); if(!hasCarb&&ids.indexOf(addFood.id)===-1 && !/snack|سناك|تحلية/.test(String(light.slotKey||'')+' '+String(light.label||''))){ var cap3=_efPortionCap({food:addFood}); var wg=Math.min(cap3,Math.round(deficit/addFood.cal*100)); wg=Math.round(wg/5)*5; if(wg>=10){ var entry={food:Object.assign({unit:'جم',mealTypes:[]},addFood),grams:0,cals:0,pro:0,carb:0,fat:0}; _efSetGrams(entry,wg); light.foods.push(entry); grew+=Number(entry.cals)||0; } } }
    if(moved<15&&grew<15) break;
  }
  for(var rc=0;rc<real.length;rc++){ _efRecalcTotals(real[rc]); }
}

// البوابة النهائية لقواعد الكمية التي يراها المستخدم في التطبيق والتصدير.
function _efEnforceOwnerServingLimits(plan){
  var meals=(plan&&plan.meals)||[];
  for(var m=0;m<meals.length;m++){
    var meal=meals[m]; if(!meal||!Array.isArray(meal.foods))continue;
    var pre=!!meal._autoPreWorkout || String(meal.slotKey||'')==='pre';
    var kept=[];
    for(var i=0;i<meal.foods.length;i++){
      var f=meal.foods[i], n=_efNameOf(f), g=Number(f.grams)||0;
      if(_efIsAddedFat(f)){
        if(g<2) continue; // الزيت/الزبدة اختياريان؛ أقل من 2 جم لا يعرض كسطر وهمي.
        _efSetGramsFine(f,Math.max(2,Math.min(_efAddedFatItemMax(plan),Math.round(g))));
      } else {
        var cap=_efPortionCap(f);
        if(g>cap) g=cap;
        // حد 50 جم للعيش في الوجبات العادية. توست قبل التمرين الصغير مقصود ومستثنى.
        if(!pre && /عيش|خبز|توست/.test(n) && g<50) g=50;
        _efSetGrams(f,g);
      }
      kept.push(f);
    }
    meal.foods=kept;
    _efRecalcTotals(meal);
  }
}
function _efDayCalories(plan){
  var meals=(plan&&plan.meals)||[],sum=0;
  for(var i=0;i<meals.length;i++)sum+=_efMealCals(meals[i]);
  return Math.round(sum);
}
function _efServingFloor(f,meal){
  var n=_efNameOf(f);
  if(_efIsAddedFat(f)) return 0;
  if(!(meal&&meal._autoPreWorkout) && /عيش|خبز|توست/.test(n)) return 50;
  if(!(meal&&meal._autoPreWorkout) && /رز|أرز|ارز|مكرونة|مكرونه|بطاطس/.test(n)) return 100;
  if(/بيض/.test(n)&&!/جبنة بيضاء/.test(n)) return 50;
  if(/فول/.test(n)&&!/سوداني/.test(n)) return 50;
  if(_efCatOf(f)==='protein'||_efCatOf(f)==='dairy') return 50;
  return 20;
}
function _efTrimDayToTolerance(plan){
  var tgt=Number(plan&&plan.targetCals)||0; if(!tgt)return;
  var meals=plan.meals||[],guard=0;
  while(_efDayCalories(plan)>tgt+50 && guard++<120){
    var candidates=[];
    for(var m=0;m<meals.length;m++){
      var meal=meals[m]; if(!meal||meal._autoPreWorkout)continue;
      var fs=meal.foods||[];
      for(var i=0;i<fs.length;i++){
        var f=fs[i],floor=_efServingFloor(f,meal),cur=Number(f.grams)||0;
        if(cur<=floor)continue;
        var cat=_efCatOf(f);
        if(_efIsVegF(f))continue;
        var priority=_efIsAddedFat(f)?0:(cat==='carb'?1:(cat==='dairy'?2:3));
        candidates.push({meal:meal,f:f,floor:floor,priority:priority,cals:Number(f.cals)||0});
      }
    }
    if(!candidates.length)break;
    candidates.sort(function(a,b){return a.priority-b.priority||b.cals-a.cals;});
    var x=candidates[0],cur=Number(x.f.grams)||0;
    if(_efIsAddedFat(x.f)){
      var ng=cur-1;
      if(ng<2){x.meal.foods=x.meal.foods.filter(function(v){return v!==x.f;});}
      else _efSetGramsFine(x.f,ng);
    }else{
      _efSetGrams(x.f,Math.max(x.floor,cur-5));
    }
    _efRecalcTotals(x.meal);
  }
}
function _efAddNaturalCarbsToTarget(plan){
  var tgt=Number(plan&&plan.targetCals)||0;if(!tgt||!_efBreadOk(plan))return;
  var meals=plan.meals||[];
  var real=meals.filter(function(m){
    var sk=String((m&&m.slotKey)||'')+' '+String((m&&m.label)||'');
    return m&&!m._autoPreWorkout&&!/snack|سناك|تحلية|pre|post|قبل التمرين|بعد التمرين/i.test(sk);
  });
  var realCount=real.length||1, guard=0;
  while(_efDayCalories(plan)<tgt-100 && guard++<80){
    real.sort(function(a,b){return _efMealCals(a)-_efMealCals(b);});
    var moved=false;
    for(var m=0;m<real.length&&_efDayCalories(plan)<tgt-100;m++){
      var meal=real[m], limit=tgt*_efSlotShareCeil(meal,realCount);
      var roomCal=limit-_efMealCals(meal); if(roomCal<10)continue;
      var foods=meal.foods||[], carb=null, breadDay=0;
      var hasTuna=foods.some(function(x){return /تونة|تونه/.test(_efNameOf(x));});
      for(var bm=0;bm<(plan.meals||[]).length;bm++)for(var bf=0;bf<((plan.meals[bm]&&plan.meals[bm].foods)||[]).length;bf++){
        var bn=_efNameOf(plan.meals[bm].foods[bf]);if(/عيش|خبز|توست/.test(bn))breadDay+=Number(plan.meals[bm].foods[bf].grams)||0;
      }
      for(var i=0;i<foods.length;i++){
        var f=foods[i],n=_efNameOf(f);
        if(_efCatOf(f)!=='carb')continue;
        if(/فول/.test(n)&&!/سوداني/.test(n))continue;
        if(hasTuna && /رز|أرز/.test(n))continue;
        // عندما يصل العيش لحد اليوم، نكمل بكارب طبيعي آخر بدل تكبيره ثم قصه في حلقة.
        if(/عيش|خبز|توست/.test(n)&&breadDay>=200)continue;
        if((Number(f.grams)||0)<_efPortionCap(f)){carb=f;break;}
      }
      if(!carb){
        // البطاطس مناسبة للفطار؛ الرز يظل خارج الفطار تماما.
        var base=_efIsBreakfast(meal)
          ? {id:'batates_bf',nameAr:'بطاطس',cat:'carb',cal:87,pro:2,carb:20,fat:0.1}
          : (hasTuna
            ? {id:'macarona',nameAr:'مكرونة مطبوخة',cat:'carb',cal:158,pro:6,carb:31,fat:1}
            : {id:'arzabydmtbwkh',nameAr:'أرز أبيض مطبوخ',cat:'carb',cal:130,pro:2.7,carb:28,fat:0.3});
        carb={food:Object.assign({unit:'جم',mealTypes:[]},base),grams:0,cals:0,pro:0,carb:0,fat:0};
        foods.push(carb); meal.foods=foods;
      }
      var per=(carb.food&&Number(carb.food.cal))||0,cur=Number(carb.grams)||0,cap=_efPortionCap(carb);
      if(!per||cur>=cap)continue;
      var needCal=Math.min(tgt-100-_efDayCalories(plan),roomCal);
      var add=Math.floor((needCal/per*100)/5)*5;
      if(cur===0)add=Math.max(50,add);
      if(add<5)add=5;
      if(cur+add>cap)add=Math.floor((cap-cur)/5)*5;
      if(add<5)continue;
      var before=Number(carb.cals)||0;_efSetGrams(carb,cur+add);
      if((Number(carb.cals)||0)>before)moved=true;
      _efRecalcTotals(meal);
    }
    if(!moved)break;
  }
}
function _efAddDynamicFatsForCalories(plan){
  var tgt=Number(plan&&plan.targetCals)||0;if(!tgt)return;
  var meals=(plan.meals||[]), used=0;
  for(var m=0;m<meals.length;m++)for(var i=0;i<(meals[m].foods||[]).length;i++)if(_efIsAddedFat(meals[m].foods[i]))used+=Number(meals[m].foods[i].grams)||0;
  var itemMax=_efAddedFatItemMax(plan),remaining=Math.max(0,_efAddedFatDayMax(plan)-used);if(remaining<2)return;
  var real=meals.filter(function(meal){return meal&&!meal._autoPreWorkout&&!/snack|سناك|pre|post|قبل التمرين|بعد التمرين/i.test(String(meal.slotKey||'')+' '+String(meal.label||''));});
  var realCount=real.length||1;
  real.sort(function(a,b){return _efMealCals(a)-_efMealCals(b);});
  for(var r=0;r<real.length&&_efDayCalories(plan)<tgt-100&&remaining>=2;r++){
    var meal=real[r], room=Math.max(0,tgt*_efSlotShareCeil(meal,realCount)-_efMealCals(meal));
    var need=Math.max(0,tgt-80-_efDayCalories(plan));
    var grams=Math.min(itemMax,remaining,Math.floor(Math.min(need,room)/8.84));
    if(grams<2)continue;
    var existing=(meal.foods||[]).find(function(f){return _efIsAddedFat(f);});
    if(existing){
      var cur=Number(existing.grams)||0, add=Math.min(itemMax-cur,grams);
      if(add>=1){_efSetGramsFine(existing,cur+add);remaining-=add;_efRecalcTotals(meal);}
      continue;
    }
    var names=(meal.foods||[]).map(_efNameOf);
    var butterOk=names.some(function(n){return /فول مدمس|بيض مقلي/.test(n);});
    var oilOk=names.some(function(n){return /سلطة|طماطم|خيار|خس|جرجير|فلفل أخضر/.test(n)||(/فول/.test(n)&&!/سوداني/.test(n))||(/جبن/.test(n)&&/بيضا|بيضاء|قريش|رودس/.test(n));});
    if(!butterOk&&!oilOk) continue;
    var base=butterOk
      ? {id:'butter',nameAr:'زبدة',cat:'fat',cal:717,pro:0.9,carb:0.1,fat:81,complement:true}
      : {id:'oil',nameAr:'زيت زيتون',cat:'fat',cal:884,pro:0,carb:0,fat:100,complement:true};
    var entry={food:base,grams:0,cals:0,pro:0,carb:0,fat:0};
    _efSetGramsFine(entry,grams);(meal.foods||(meal.foods=[])).push(entry);remaining-=grams;_efRecalcTotals(meal);
  }
}
function _efCloseOwnerCalorieTolerance(plan){
  var tgt=Number(plan&&plan.targetCals)||0;if(!tgt)return;
  _efTrimDayToTolerance(plan);
  if(_efDayCalories(plan)<tgt-100){
    // العشاء الخفيف مسموح فقط عندما لا يجعل اليوم ناقصا؛ وإلا نكرر الغداء/الفطار كما طلب المالك.
    var light=(plan.meals||[]).find(function(m){return m&&m._lightFruitYogurt;});
    if(light){light._lightFruitYogurt=false;_efMirrorDinner(plan);_efEnforceOwnerServingLimits(plan);}
    _efGrowMainsToTarget(plan);
    // التكبير قد يستهلك العيش فوق حد اليوم؛ افرض السقف قبل قرار الإغلاق التالي.
    _efEnforceDailyCaps(plan);
    if(_efDayCalories(plan)<tgt-100)_efAddNaturalCarbsToTarget(plan);
    if(_efDayCalories(plan)<tgt-100)_efAddDynamicFatsForCalories(plan);
  }
  _efTrimDayToTolerance(plan);
  plan._calorieGap=Math.round(tgt-_efDayCalories(plan));
}

function _efAddEntry(meal,food,grams){
  if(!meal||!food)return null;
  var e={food:food,grams:0,cals:0,pro:0,carb:0,fat:0};
  _efSetGrams(e,grams);(meal.foods||(meal.foods=[])).push(e);return e;
}
function _efRotationFood(plan){
  var specs=[
    ['kfta_mshwya_ala_alfhm',null],
    ['kfta_frakh',null],
    ['kbda_wnwans_frakh',{id:'kbda_wnwans_frakh',nameAr:'كبد وقوانص فراخ',cat:'protein',cal:143,pro:22,carb:1,fat:5}],
    ['kbda_baqary_esk',{id:'kbda_baqary_esk',nameAr:'كبدة إسكندراني',cat:'protein',cal:191,pro:26,carb:5,fat:7}],
    ['lhm_bqry_mslwq',null],
    ['sdr_frakh_mshwy',null],
    ['fylyh_blty',null],
    ['qta_twna_balzyt',null]
  ];
  var start=((Number(plan._dayOfCycle)||0)+(Number(plan._weekNumber)-1)*2)%specs.length;
  for(var i=0;i<specs.length;i++){
    var sp=specs[(start+i)%specs.length],f=_efFoodV3(sp[0])||sp[1];
    if(!f||_efBannedName(plan,f.nameAr))continue;
    try{if(!passesHealth(f,plan._healthConditions||[]))continue;}catch(_){}
    return f;
  }
  return _efFoodV3('sdr_frakh_mshwy');
}
function _efIsAnimalMain(f){
  var n=_efNameOf(f);return /فراخ|دجاج|لحم|لحمة|كفتة|كفته|كبد|قوانص|سمك|بلطي|بوري|ماكريل|سردين|تونة|تونه/.test(n);
}
function _efApplyWeeklyFoodRotation(plan){
  var chosen=_efRotationFood(plan);if(!chosen)return;
  var meals=plan.meals||[];
  for(var i=0;i<meals.length;i++){
    var m=meals[i],slot=String(m&&m.slotKey||'');if(!m||!Array.isArray(m.foods)||!/(breakfast|lunch|dinner)/.test(slot))continue;
    for(var j=0;j<m.foods.length;j++)if(_efIsAnimalMain(m.foods[j])){
      var g=Math.max(100,Math.min(250,Number(m.foods[j].grams)||150));
      m.foods[j].food=chosen;_efSetGrams(m.foods[j],g);
    }
    _efRecalcTotals(m);
  }
  // القريش تظل الاختيار الأول في أغلب الأسبوع، مع يوم لرودس ويوم للرومي.
  var day=Number(plan._dayOfCycle)||0,cheeseId=day===2?'jbn_rwds':(day===5?'jbn_rwmy':'');
  if(cheeseId){
    var alt=_efFoodV3(cheeseId);
    if(alt&&!_efBannedName(plan,alt.nameAr))for(var b=0;b<meals.length;b++){
      var bm=meals[b];if(!bm||!_efIsBreakfast(bm))continue;
      for(var q=0;q<(bm.foods||[]).length;q++)if(/قريش/.test(_efNameOf(bm.foods[q]))){
        bm.foods[q].food=alt;_efSetGrams(bm.foods[q],cheeseId==='jbn_rwmy'?40:60);break;
      }
    }
  }
}
function _efCanonicalCarbBase(kind){
  if(kind==='bread')return {id:'ayshbldy',nameAr:'عيش بلدي',cat:'carb',cal:265,pro:8.5,carb:55,fat:1.5};
  if(kind==='pasta')return {id:'mkrwnh_mtbwkh',nameAr:'مكرونة مطبوخة',cat:'carb',cal:158,pro:6,carb:31,fat:1};
  return {id:'arzabydmtbwkh',nameAr:'أرز أبيض مطبوخ',cat:'carb',cal:130,pro:2.7,carb:28,fat:.3};
}
function _efNormalizeMainCarbPairing(plan){
  var meals=(plan&&plan.meals)||[];
  for(var i=0;i<meals.length;i++){
    var m=meals[i],slot=String(m&&m.slotKey||''); if(!m||!Array.isArray(m.foods)||!/(lunch|dinner)/.test(slot))continue;
    var p=m.foods.find(_efIsAnimalMain); if(!p)continue;
    var pn=_efNameOf(p),tuna=/تونة|تونه/.test(pn),fish=!tuna&&/سمك|بلطي|بوري|ماكريل|سردين|سلمون|بلاميط|قاروص|دنيس/.test(pn);
    var special=/كفتة|كفته|كبدة إسكندراني|كبد وقوانص/.test(pn);
    var plainMeat=!special&&!fish&&!tuna&&/لحم|لحمة|بقري|بتلو|ستيك|بفتيك/.test(pn);
    var chicken=!special&&/فراخ|دجاج|صدر|ورك|جناح/.test(pn);
    var removed=0;
    m.foods=m.foods.filter(function(f){
      var n=_efNameOf(f),bad=((plainMeat||chicken)&&/عيش|خبز|توست/.test(n))||(fish&&/مكرونة|مكرونه|باستا/.test(n))||(tuna&&/أرز|ارز|رز/.test(n));
      if(bad){removed+=Number(f.cals)||0;return false;} return true;
    });
    var hasCarb=m.foods.some(function(f){return _efCatOf(f)==='carb'&&/أرز|ارز|رز|عيش|خبز|توست|مكرونة|مكرونه|بطاطس/.test(_efNameOf(f));});
    if(!hasCarb&&_efBreadOk(plan)){
      var kind=tuna?'bread':(plainMeat||fish?'rice':(special?'bread':'pasta'));
      var base=_efCanonicalCarbBase(kind),g=kind==='bread'?60:Math.max(100,Math.min(180,Math.round((removed||150)/(base.cal||130)*100/5)*5));
      _efAddEntry(m,base,g);
    }
    _efRecalcTotals(m);
  }
}
function _efEnsureCookedVegRotation(plan){
  plan._cookedVegChecks=(Number(plan._cookedVegChecks)||0)+1;
  var diet=_efDietKey(plan); if(!/balanced|mediterranean|carbcycle/.test(diet))return;
  var day=(Number(plan._dayOfCycle)||0)+(Number(plan._weekNumber)||1);
  if(day%2!==0)return; // تدوير مرن: يظهر في أيام مناسبة فقط، وليس يوميًا
  var choices=[
    {id:'khodar_meshkl',nameAr:'خضار مشكل مطبوخ',cat:'cooked_veg',cal:65,pro:3,carb:11,fat:1},
    {id:'kosa_matbokha',nameAr:'كوسة مطبوخة',cat:'cooked_veg',cal:40,pro:2,carb:6,fat:1},
    {id:'shorbet_lahma',nameAr:'شوربة مرقة لحمة',cat:'soup',cal:44,pro:3,carb:3,fat:2}
  ];
  for(var i=0;i<(plan.meals||[]).length;i++){
    var m=plan.meals[i],slot=String(m&&m.slotKey||'');if(!m||!/(lunch|dinner)/.test(slot)||!Array.isArray(m.foods))continue;
    var names=m.foods.map(_efNameOf).join(' ');if(/سمك|بلطي|بوري|ماكريل|سردين|تونة|تونه|كفتة|كبدة|كبد وقوانص|قوانص/.test(names))continue;
    if(m.foods.some(function(f){return _efIsCookedVegV3(f)||_efIsSoupV3(f);}))continue;
    // في يوم الخضار المطبوخ نستبدل السلطة، لأن القاعدة تمنع جمعهما.
    m.foods=m.foods.filter(function(f){return !_efIsVegF(f)||!_efIsSaladName(_efNameOf(f));});
    var base=choices[Math.abs(day)%choices.length];
    try{if(_efBannedName(plan,base.nameAr)||!passesHealth(base,plan._healthConditions||[]))continue;}catch(_){}
    _efAddEntry(m,base,180);plan._cookedVegApplied=(Number(plan._cookedVegApplied)||0)+1;_efRecalcTotals(m);
  }
}
function _efEnsureNaturalYogurtVariety(plan){
  var day=(Number(plan._dayOfCycle)||0)+(Number(plan._weekNumber)||1);if(day%3!==2)return;
  var meals=plan.meals||[],used=0;for(var i=0;i<meals.length;i++)for(var j=0;j<((meals[i]&&meals[i].foods)||[]).length;j++)if(/زبادي/.test(_efNameOf(meals[i].foods[j])))used+=Number(meals[i].foods[j].grams)||0;
  if(used>0||used>=200)return;
  var dest=meals.find(function(m){return m&&/snack|سناك|تحلية/.test(String(m.slotKey||'')+' '+String(m.label||''));});
  if(!dest)return; // تنويع اختياري؛ لا نحوّل وجبة رئيسية لزبادي بالقوة
  var base={id:'zbadytbyay',nameAr:'زبادي طبيعي',cat:'dairy',cal:61,pro:3.5,carb:4.7,fat:3.3};
  _efAddEntry(dest,base,Math.min(200,150));_efRecalcTotals(dest);
}
function _efEnsureMainMealStructure(plan){
  plan._mainStructureRuns=(Number(plan._mainStructureRuns)||0)+1;
  var diet=_efDietKey(plan),day=Number(plan._dayOfCycle)||0,meals=plan.meals||[];
  if(diet==='carnivore')return;
  for(var i=0;i<meals.length;i++){
    var m=meals[i],slot=String(m&&m.slotKey||'');if(!m||!Array.isArray(m.foods)||!/(breakfast|lunch|dinner)/.test(slot))continue;
    var names=m.foods.map(_efNameOf),hasProt=m.foods.some(function(f){var c=_efCatOf(f);return _efIsAnimalMain(f)||c==='protein'||c==='dairy'||c==='cheese'||c==='egg'||/بيض|جبن|قريش|فول مدمس/.test(_efNameOf(f));});
    if(!hasProt){var pf=_efRotationFood(plan);if(pf)_efAddEntry(m,pf,150);}
    var hasVeg=m.foods.some(function(f){var n=_efNameOf(f);return !/زيتون مخلل/.test(n)&&(_efIsVegF(f)||_efIsCookedVegV3(f)||/سلطة|طماطم|خيار|خس|جرجير|فلفل أخضر/.test(n));});
    if(!hasVeg){
      _efAddEntry(m,{id:'tmatm',nameAr:'طماطم',cat:'salad_veg',cal:18,pro:.9,carb:3.9,fat:.2},70);
      _efAddEntry(m,{id:'khyar',nameAr:'خيار',cat:'salad_veg',cal:16,pro:.7,carb:3.6,fat:.1},60);
      _efAddEntry(m,{id:'flfl',nameAr:'فلفل أخضر',cat:'salad_veg',cal:20,pro:.9,carb:4.6,fat:.2},50);
    }
    var needCarb=(diet==='balanced'||diet==='mediterranean'||(diet==='carbcycle'&&day%2===0));
    var hasCarb=m.foods.some(function(f){var n=_efNameOf(f);return _efCatOf(f)==='carb'&&/أرز|ارز|رز|عيش|خبز|توست|بطاطس|مكرونة|مكرونه|رايس كيك/.test(n);});
    if(needCarb&&!hasCarb){
      var tuna=m.foods.some(function(f){return /تونة|تونه/.test(_efNameOf(f));});
      _efAddEntry(m,tuna?{id:'ayshbldy',nameAr:'عيش بلدي',cat:'carb',cal:265,pro:8.5,carb:55,fat:1.5}:{id:'arzabydmtbwkh',nameAr:'أرز أبيض مطبوخ',cat:'carb',cal:130,pro:2.7,carb:28,fat:.3},tuna?60:120);
    }
    if(needCarb){
      var starch=m.foods.find(function(f){return /رز|أرز|ارز|مكرونة|مكرونه|بطاطس/.test(_efNameOf(f));});
      if(starch&&(Number(starch.grams)||0)<100)_efSetGrams(starch,100);
    }
    _efRecalcTotals(m);
  }
}
function _efEnforceEggRange(plan){
  var eggs=[];for(var m=0;m<(plan.meals||[]).length;m++)for(var i=0;i<((plan.meals[m]&&plan.meals[m].foods)||[]).length;i++){
    var f=plan.meals[m].foods[i];if(_efCatOf(f)==='egg'||/(^|\s)بيض(\s|$)/.test(_efNameOf(f)))eggs.push({f:f,meal:plan.meals[m]});
  }
  var total=eggs.reduce(function(s,x){return s+(Number(x.f.grams)||0);},0);
  if(total>0&&total<100){_efSetGrams(eggs[0].f,(Number(eggs[0].f.grams)||0)+(100-total));_efRecalcTotals(eggs[0].meal);}
}
function _efFillTrainingPreGap(plan){
  var diet=_efDietKey(plan);if(diet==='keto'||diet==='lowcarb'||diet==='carnivore')return;
  var tgt=Number(plan&&plan.targetCals)||0,pre=(plan.meals||[]).find(function(m){return m&&(m._autoPreWorkout||String(m.slotKey)==='pre');});
  if(!tgt||!pre||_efDayCalories(plan)>=tgt-100)return;
  var limit=tgt*.20,room=Math.max(0,limit-_efMealCals(pre));if(room<10)return;
  var fruit=(pre.foods||[]).find(function(f){return _efCatOf(f)==='fruit';});
  if(fruit){
    var cur=Number(fruit.grams)||0,per=(fruit.food&&Number(fruit.food.cal))||0;
    var add=Math.min(300-cur,Math.floor(Math.min(room,tgt-90-_efDayCalories(plan))/per*100));
    if(add>0){_efSetGrams(fruit,cur+add);_efRecalcTotals(pre);room=Math.max(0,limit-_efMealCals(pre));}
  }
  if(_efDayCalories(plan)<tgt-100&&room>40&&(pre.foods||[]).filter(function(f){return _efCatOf(f)!=='drink';}).length<2){
    var perSp=86,need=Math.min(room,tgt-90-_efDayCalories(plan));
    var grams=Math.max(50,Math.min(250,Math.floor(need/perSp*100/5)*5));
    _efAddEntry(pre,{id:'sweet_potato_pre',nameAr:'بطاطا مسلوقة',cat:'carb',cal:perSp,pro:1.6,carb:20,fat:.1},grams);_efRecalcTotals(pre);
  }
  // لو ما زالت فجوة بعد الفاكهة، كبّر بطاطا ما قبل التمرين الموجودة فقط
  // داخل سقف 20% للوجبة؛ لا ننقل العجز إلى بروتين ضخم في الوجبات الرئيسية.
  room=Math.max(0,limit-_efMealCals(pre));
  var preCarb=(pre.foods||[]).find(function(f){return _efCatOf(f)==='carb'&&/بطاطا/.test(_efNameOf(f));});
  if(preCarb&&_efDayCalories(plan)<tgt-100&&room>5){
    var pc=Number(preCarb.grams)||0,pp=(preCarb.food&&Number(preCarb.food.cal))||86;
    var pa=Math.min(600-pc,Math.floor(Math.min(room,tgt-90-_efDayCalories(plan))/pp*100/5)*5);
    if(pa>=5){_efSetGramsFine(preCarb,pc+pa);_efRecalcTotals(pre);}
  }
}
function _efFillTwoMealEggGap(plan){
  var tgt=Number(plan&&plan.targetCals)||0;
  var real=(plan.meals||[]).filter(function(m){return m&&!m._autoPreWorkout&&!/snack|سناك|pre|post|قبل التمرين|بعد التمرين/i.test(String(m.slotKey||'')+' '+String(m.label||''));});
  var hasPre=(plan.meals||[]).some(function(m){return m&&(m._autoPreWorkout||String(m.slotKey)==='pre');});
  if(!tgt||real.length!==2||!hasPre||_efDayCalories(plan)>=tgt-100)return;
  var used=0;for(var a=0;a<(plan.meals||[]).length;a++)for(var b=0;b<((plan.meals[a]&&plan.meals[a].foods)||[]).length;b++){var en=_efNameOf(plan.meals[a].foods[b]);if(/بيض/.test(en)&&!/جبنة بيضاء/.test(en))used+=Number(plan.meals[a].foods[b].grams)||0;}
  var room=Math.max(0,300-used);
  for(var i=0;i<real.length&&room>=50&&_efDayCalories(plan)<tgt-100;i++){
    var existing=(real[i].foods||[]).find(function(f){var n=_efNameOf(f);return /بيض/.test(n)&&!/جبنة بيضاء/.test(n);});
    if(existing){var add=Math.min(150-(Number(existing.grams)||0),room);if(add>0){_efSetGrams(existing,(Number(existing.grams)||0)+add);room-=add;}}
    else {var g=Math.min(130,room);_efAddEntry(real[i],{id:'byd_mslwq',nameAr:'بيض مسلوق',cat:'egg',cal:155,pro:13,carb:1.1,fat:11},g);room-=g;}
    _efRecalcTotals(real[i]);
  }
}
function _efFillTwoMealDenseCarb(plan){
  var tgt=Number(plan&&plan.targetCals)||0;
  var real=(plan.meals||[]).filter(function(m){return m&&!m._autoPreWorkout&&!/snack|سناك|pre|post|قبل التمرين|بعد التمرين/i.test(String(m.slotKey||'')+' '+String(m.label||''));});
  if(!tgt||real.length!==2||_efDayCalories(plan)>=tgt-100||_efIsKetoPlan(plan)||_efDietKey(plan)==='lowcarb')return;
  var sorted=real.slice().sort(function(a,b){return _efMealCals(a)-_efMealCals(b);}),meal=sorted[0],other=sorted[1];
  var hasStarch=(meal.foods||[]).some(function(f){return /عيش|خبز|توست|رز|أرز|ارز|مكرونة|مكرونه|بطاطس|شوفان/.test(_efNameOf(f));});
  if(hasStarch)return;
  var need=Math.max(0,Math.min(tgt-80-_efDayCalories(plan),_efMealCals(other)-_efMealCals(meal)));
  if(need<50)return;
  var grams=Math.max(80,Math.min(200,Math.ceil(need/389*100/5)*5));
  var dense=_efIsBreakfast(meal)?{id:'ayshasmr',nameAr:'عيش أسمر',cat:'carb',cal:247,pro:9,carb:48,fat:2}:{id:'arzabydmtbwkh',nameAr:'أرز أبيض مطبوخ',cat:'carb',cal:130,pro:2.7,carb:28,fat:.3};
  grams=Math.max(50,Math.min(200,Math.ceil(need/dense.cal*100/5)*5));
  _efAddEntry(meal,dense,grams);
  _efRecalcTotals(meal);
}
function _efCloseTwoMealCarbs(plan){
  var tgt=Number(plan&&plan.targetCals)||0,real=(plan.meals||[]).filter(function(m){return m&&!m._autoPreWorkout&&!/snack|سناك|pre|post|قبل التمرين|بعد التمرين/i.test(String(m.slotKey||'')+' '+String(m.label||''));});
  if(!tgt||real.length!==2||_efIsKetoPlan(plan)||_efDietKey(plan)==='lowcarb')return;
  var guard=0;
  while(_efDayCalories(plan)<tgt-100&&guard++<160){
    real.sort(function(a,b){return _efMealCals(a)-_efMealCals(b);});var changed=false;
    for(var i=0;i<real.length&&!changed;i++){
      var carb=(real[i].foods||[]).find(function(f){return _efCatOf(f)==='carb'&&/عيش|خبز|توست|رز|أرز|ارز|مكرونة|مكرونه|بطاطس/.test(_efNameOf(f));});if(!carb)continue;
      var n=_efNameOf(carb),cur=Number(carb.grams)||0,cap=_efPortionCap(carb);
      if(/عيش|خبز|توست/.test(n)){var bread=0;for(var m=0;m<(plan.meals||[]).length;m++)for(var j=0;j<((plan.meals[m]&&plan.meals[m].foods)||[]).length;j++)if(/عيش|خبز|توست/.test(_efNameOf(plan.meals[m].foods[j])))bread+=Number(plan.meals[m].foods[j].grams)||0;cap=Math.min(cap,cur+Math.max(0,200-bread));}
      if(cur+5<=cap){_efSetGramsFine(carb,cur+5);_efRecalcTotals(real[i]);changed=true;}
    }
    if(!changed)break;
  }
}
function _efCloseFinalMainGap(plan){
  var tgt=Number(plan&&plan.targetCals)||0;if(!tgt)return;
  var mains=(plan.meals||[]).filter(function(m){var sk=String(m&&m.slotKey||'');return m&&!m._autoPreWorkout&&/breakfast|lunch|dinner/.test(sk);});
  var guard=0;
  while(_efDayCalories(plan)<tgt-85&&guard++<300){
    mains.sort(function(a,b){return _efMealCals(a)-_efMealCals(b);});
    var changed=false;
    for(var i=0;i<mains.length&&!changed;i++){
      var m=mains[i],room=tgt*(mains.length<=2?.50:.40)-_efMealCals(m);if(room<2)continue;
      var choices=(m.foods||[]).filter(function(f){var n=_efNameOf(f),c=_efCatOf(f);return !_efIsAddedFat(f)&&!_efIsVegF(f)&&!/(^|\s)بيض(\s|$)/.test(n)&&!/عيش|خبز|توست/.test(n)&&
        (c==='carb'||c==='dairy'||c==='protein'||c==='protein_chicken'||c==='protein_meat'||c==='fish')&&(Number(f.grams)||0)<_efPortionCap(f);});
      choices.sort(function(a,b){var ac=_efCatOf(a)==='carb'?0:1,bc=_efCatOf(b)==='carb'?0:1;return ac-bc;});
      if(!choices.length) choices=(m.foods||[]).filter(function(f){return _efIsVegF(f)&&(Number(f.grams)||0)<150;});
      for(var j=0;j<choices.length;j++){
        var f=choices[j],cur=Number(f.grams)||0,cap=_efPortionCap(f),per=(f.food&&Number(f.food.cal))||0;if(!per||cur+5>cap)continue;
        var delta=per*.05;if(delta>room+3)continue;
        _efSetGramsFine(f,cur+5);_efRecalcTotals(m);changed=true;break;
      }
    }
    if(!changed)break;
  }
}

function _efBalanceFinalOneCarb(plan){
  var tgt=Number(plan&&plan.targetCals)||0;if(!tgt)return;
  var mains=(plan.meals||[]).filter(function(m){return m&&!m._autoPreWorkout&&/breakfast|lunch|dinner/.test(String(m.slotKey||''));});
  if(mains.length<2)return;
  var cap=tgt*(mains.length<=2?0.50:0.40),guard=0;
  while(_efDayCalories(plan)<tgt-90&&guard++<1200){
    mains.sort(function(a,b){return _efMealCals(a)-_efMealCals(b);});var changed=false;
    for(var i=0;i<mains.length&&!changed;i++){
      var m=mains[i],room=cap-_efMealCals(m);if(room<2)continue;
      var f=(m.foods||[]).find(function(x){return _efCatOf(x)==='carb'&&!/بطاطا/.test(_efNameOf(x));});
      if(!f)continue;var per=(f.food&&Number(f.food.cal))||0,cur=Number(f.grams)||0;if(!per||cur>=800||per*.05>room+1)continue;
      _efSetGramsFine(f,cur+5);_efRecalcTotals(m);changed=true;
    }
    if(!changed)break;
  }
}
function _efCleanFinalSnacks(plan){
  for(var i=0;i<(plan.meals||[]).length;i++){
    var m=plan.meals[i],sk=String(m&&m.slotKey||'')+' '+String(m&&m.label||'');
    if(!m||!Array.isArray(m.foods)||!/snack|سناك|تحلية/i.test(sk))continue;
    m.foods=m.foods.filter(function(f){
      var n=_efNameOf(f),c=_efCatOf(f);
      if(/زبادي/.test(n)||c==='fruit'||c==='nut'||c==='snack'||c==='snackitem')return true;
      return /شوكولات|فشار|ترمس|سوداني|مكسرات/.test(n);
    });
    _efRecalcTotals(m);
  }
}
function _efFinalizeOwnerPlan(plan){
  _efEnforceOwnerServingLimits(plan);
  _efEnforceFatPairing(plan);
  _efSizeAddedFats(plan);
  _efEnforceOwnerServingLimits(plan);
  _efEnforceDailyCaps(plan);
  _efHardCapMeals(plan);
  _efCloseOwnerCalorieTolerance(plan);
  _efEnforceOwnerServingLimits(plan);
  _efEnforceDailyCaps(plan);
  _efHardCapMeals(plan);
  _efCloseOwnerCalorieTolerance(plan);
  _efEnforceOwnerServingLimits(plan);
  _efEnforceDailyCaps(plan);
  // أي قص يومي أخير قد يفتح فجوة؛ الإغلاق النهائي يبدأ من خطة ملتزمة بالسقوف.
  _efCloseOwnerCalorieTolerance(plan);
  _efEnforceOwnerServingLimits(plan);
  var meals=plan.meals||[],c=0,pr=0,cb=0,ft=0;
  for(var i=0;i<meals.length;i++){var t=_efRecalcTotals(meals[i]);c+=t.cals;pr+=t.pro;cb+=t.carb;ft+=t.fat;}
  if(plan.totals&&typeof plan.totals==='object'){plan.totals.cals=Math.round(c);plan.totals.pro=Math.round(pr);plan.totals.carb=Math.round(cb);plan.totals.fat=Math.round(ft);}
  plan._calorieGap=Math.round((Number(plan.targetCals)||0)-c);
}

// يعوض أي نقص نتج عن التنظيف النهائي بزيادة كمية صنف موجود بالفعل؛ لا يضيف
// سطرا جديدا ولا يكرر الصنف، ويحافظ على حد 40% للوجبة عند وجود 3 وجبات.
function _efFillRequestedCalorieFloor(plan){
  var tgt=Number(plan&&plan.targetCals)||0;if(!tgt)return;
  var meals=(plan.meals||[]).filter(function(m){var sk=String(m&&m.slotKey||'')+' '+String(m&&m.label||'');return m&&!m._autoPreWorkout&&!/snack|سناك|تحلية|pre|post|قبل التمرين|بعد التمرين/i.test(sk);});
  var guard=0;
  while(_efDayCalories(plan)<tgt-95&&guard++<80){
    var deficit=tgt-75-_efDayCalories(plan),best=null;
    for(var i=0;i<meals.length;i++){
      var meal=meals[i],room=meals.length>=3
        ? Math.max(0,tgt*.40-_efMealCals(meal))
        : Math.max(0,(tgt-80)*.50-_efMealCals(meal));
      if(room<5)continue;
      for(var j=0;j<(meal.foods||[]).length;j++){
        var f=meal.foods[j],n=_efNameOf(f),cat=_efCatOf(f);
        if(_efIsAddedFat(f)||_efIsVegF(f)||(/بيض/.test(n)&&!/جبنة بيضاء/.test(n))||(/بطاطا/.test(n)&&!/بطاطس/.test(n)))continue;
        // مسموح تكبير البروتين حتى سقف 250جم فقط؛ المنع الحقيقي هو تجاوز
        // سقف الحصة، لا ترك اليوم ناقصًا ثم تعويضه بوجبة عبثية.
        if(cat!=='carb'&&cat!=='dairy'&&cat!=='protein'&&cat!=='fish'&&cat!=='protein_chicken'&&cat!=='protein_meat')continue;
        var per=(f.food&&Number(f.food.cal))||0;if(per<=0)continue;
        var cap=_efPortionCap(f),cur=Number(f.grams)||0;if(cur>=cap)continue;
        var addCal=Math.min(deficit,room,(cap-cur)*per/100);
        if(!best||addCal>best.addCal)best={meal:meal,f:f,per:per,addCal:addCal};
      }
    }
    if(!best){
      // في خطط الوجبتين فقط قد تكون كل الحصص الأساسية وصلت سقفها ويتبقى
      // فرق صغير جدًا. نوزعه على خضار السلطة بدل كسر سقف البروتين أو الزيت.
      for(var vi=0;vi<meals.length&&!best;vi++)for(var vj=0;vj<(meals[vi].foods||[]).length;vj++){
        var vf=meals[vi].foods[vj],vg=Number(vf.grams)||0,vper=(vf.food&&Number(vf.food.cal))||0;
        if(_efIsVegF(vf)&&vg<100&&vper>0)best={meal:meals[vi],f:vf,per:vper,addCal:Math.min(deficit,(100-vg)*vper/100)};
      }
    }
    if(!best||best.addCal<0.5)break;
    var addG=Math.max(1,Math.round(best.addCal/best.per*100));
    var before=Number(best.f.cals)||0;
    _efSetGramsFine(best.f,(Number(best.f.grams)||0)+addG);_efRecalcTotals(best.meal);
    if((Number(best.f.cals)||0)<=before)break;
  }
}

function _efSanitizePlan(plan){
  const meals = (plan && plan.meals) || [];
  try { _efMirrorDinner(plan); } catch(_mdErr){ plan.dinnerMirrorError = String((_mdErr&&_mdErr.message)||_mdErr); }
  try { _efFixLoneBreakfastVeg(plan); } catch(_lvErr){ plan.saladFixError = String((_lvErr&&_lvErr.message)||_lvErr); }
  // [FIX-SALAD-3] طبق السلطة = 3 مكونات، ونفس الشكل في كل وجبات اليوم.
  try { _efEnsureSaladPlate(plan); } catch(_s3Err){ plan.saladPlateError = String((_s3Err&&_s3Err.message)||_s3Err); }
  // [FIX-BREAD-1] العيش/النشويات ماتتشالش من الفطار ولا من أي وجبة رئيسية.
  try { _efEnsureMainCarb(plan); } catch(_bcErr){ plan.breadFixError = String((_bcErr&&_bcErr.message)||_bcErr); }
  try { _efOwnerPre(plan); } catch(_opErr){ plan.ownerPreError = String((_opErr&&_opErr.message)||_opErr); }
  // عدد الوجبات الفعلية (ماعدا وجبة قبل التمرين). لو وجبتين بس
  // بنمنع تكديس أكتر من نوع كارب/بروتين في نفس الوجبة.
  const realMeals = meals.filter(function(mm){ return !(mm && mm._autoPreWorkout); }).length;
  const twoMeals = realMeals <= 2;
  let dCals = 0, dPro = 0, dCarb = 0, dFat = 0;
  for (var m = 0; m < meals.length; m++){
    const meal = meals[m];
    const foods = (meal && meal.foods) || [];
    for (var i = 0; i < foods.length; i++){ const f = foods[i]; const g = Number(f.grams) || 0; const cap = _efPortionCap(f); _efSetGrams(f, g > cap ? cap : g); }
    const names = foods.map(_efNameOf);
    // قاعدة صاحب المشروع: مستحيل نوعين عيش في وجبة واحدة
    // نسيب الأكبر في الجرامات ونشيل الباقي ونورد جراماته للمتبقي
    _efDedupeBread(meal);
    // وجبتين بس → ممنوع تكديس كارب أو بروتين (نرفع الكمية مش الأصناف)
    if (twoMeals && !(meal && meal._autoPreWorkout)){
      _efDedupeCategory(meal, 'carb');
      _efDedupeCategory(meal, 'protein');
    }
    const foods2 = (meal && meal.foods) || foods;
    const names2 = foods2.map(_efNameOf);
    const kept = foods2.filter(function(f){ return _efPairingKeep(f, names2, meal); });
    if (kept.length >= 2 && kept.length < foods.length) meal.foods = kept;   // never strip a meal bare
    // ربط الزيت/الزبدة بالعنصر المرتبط (للعرض inline)
    _efPairFats(meal);
    // ترتيب العرض: بروتين ← سلطة ← خضار مطبوخ ← كارب ← إضافات
    _efOrderMealFoods(meal);
    const t = _efRecalcTotals(meal);
    dCals += t.cals; dPro += t.pro; dCarb += t.carb; dFat += t.fat;
  }
  // [CALORIE-CLOSE-FIX] اقفل فجوة السعرات بعد القص.
  // السقوف الواقعية فوق بتقص الجرامات لتحت، فكان اليوم بيخرج ناقص 400-800 سعرة
  // وبيظهر للمستخدم "فاضلك 635 سعرة" مع إن الخطة مفروض تكون مكتملة.
  // الحل: نوزع الناقص على الأصناف اللي لسه تحت سقفها الواقعي، من غير ما نكسر
  // أي سقف ومن غير ما نكبر الخضار (مالوش معنى نزود خس عشان سعرات).
  const _tgt = Number(plan.targetCals) || 0;
  if (_tgt > 0 && dCals < _tgt * 0.97){
    let _guard = 0;
    while (dCals < _tgt * 0.97 && _guard++ < 40){
      let _moved = false;
      for (var m2 = 0; m2 < meals.length; m2++){
        // وجبة قبل التمرين لازم تفضل خفيفة — مانكبرهاش عشان نقفل فجوة اليوم.
        if (meals[m2] && meals[m2]._autoPreWorkout) continue;
        const _foods = (meals[m2] && meals[m2].foods) || [];
        for (var j = 0; j < _foods.length; j++){
          if (dCals >= _tgt * 0.97) break;
          const f2 = _foods[j];
          const c2 = _efCatOf(f2);
          if (c2 === 'veg' || c2 === 'veggie' || c2 === 'vegetable' || c2 === 'vegetables') continue;
          const _per100 = (f2.food && f2.food.cal != null) ? Number(f2.food.cal) : 0;
          if (!_per100) continue;
          const _cap = _efPortionCap(f2);
          const _cur = Number(f2.grams) || 0;
          if (_cur >= _cap) continue;
          let _addG = Math.min(_cap - _cur, Math.max(5, Math.round((_tgt - dCals) / _per100 * 100)));
          _addG = Math.round(_addG / 5) * 5;
          if (_addG < 5) continue;
          const _before = Number(f2.cals) || 0;
          _efSetGrams(f2, _cur + _addG);
          dCals += (Number(f2.cals) || 0) - _before;
          _moved = true;
        }
      }
      if (!_moved) break;
    }
    // لو كل الأصناف وصلت سقفها ولسه فيه ناقص (بيحصل مع أهداف التضخيم
    // العالية)، نضيف صنف جديد حقيقي للوجبة بدل ما نسيب اليوم ناقص.
    if (dCals < _tgt * 0.97){
      const _TU = {
        bread:  { id:'ayshbldy',      nameAr:'عيش بلدي',     cat:'carb',    cal:265, pro:8.5,  carb:55, fat:1.5 },
        breadBrown: { id:'ayshasmr',  nameAr:'عيش أسمر',     cat:'carb',    cal:247, pro:9,    carb:48, fat:2 },
        potato: { id:'btatsmslwqh',   nameAr:'بطاطس مسلوقة', cat:'carb', cal:87,  pro:1.9,  carb:20, fat:0.1 },
        rice:   { id:'arzabydmtbwkh', nameAr:'أرز أبيض مطبوخ', cat:'carb', cal:130, pro:2.7, carb:28, fat:0.3 },
        yogurt: { id:'zbadytbyay',    nameAr:'زبادي طبيعي', cat:'dairy',   cal:61,  pro:3.5,  carb:4.7, fat:3.3 },
        dates:  { id:'tmr',           nameAr:'تمر',           cat:'fruit',   cal:313, pro:2.5,  carb:75, fat:0.4 },
        peanut: { id:'swdany_mhms',   nameAr:'سوداني محمص', cat:'nut',    cal:567, pro:26,   carb:16, fat:49 }
      };
      // [OWNER-RULE] إقفال فجوة السعرات بإضافة صنف لازم يحترم نفس قواعد
      // المطبخ المصري: ممنع تكديس كارب/بروتين في نفس الوجبة،
      // وممنوع رز في الفطار. قبل كده الطبقة دي كانت بتتجاوز القواعد
      // وتحط عيش + أرز + سوداني في فطار واحد — وده الغلط اللي اتشاف.
      const _hasCat4 = function(meal, cat){
        const fs = (meal && meal.foods) || [];
        for (var z = 0; z < fs.length; z++){ if (_efCatOf(fs[z]) === cat) return true; }
        return false;
      };
      const _plan4Slot = function(meal){
        const slot = String((meal && meal.slotKey) || '');
        // [EGY-v71] من غير رز ولا تمر في الفطار — التمر/الفاكهة مكانها السناك وقبل/بعد التمرين بس.
        // [FIX #4] عناصر السناك (سوداني/مكسرات) ممنوعة في الوجبات الرئيسية —
        // مكانها السناك وقبل/بعد التمرين بس، زي قاعدة التمر/الفاكهة فوق بالظبط.
        // (السوداني cat:'nut' فماكانش بيتمنع بفحص التكديس، عشان كده كان بيطلع في الفطار.)
        // [FIX-BREAD-1] فجوة سعرات الفطار تتقفل بالعيش/البطاطس الأولى مش بزبادي بس.
        if (_efIsBreakfast(meal)) return _efBreadOk(plan) ? [_TU.breadBrown, _TU.potato, _TU.yogurt] : [_TU.yogurt];
        if (slot === 'dinner') return [_TU.yogurt, _TU.rice];
        if (slot === 'snack' || slot === 'pre' || slot === 'post') return [_TU.dates, _TU.peanut];
        return [_TU.bread, _TU.rice];
      };
      for (var m4 = 0; m4 < meals.length && dCals < _tgt * 0.97; m4++){
        const _meal4 = meals[m4];
        if (!_meal4 || !Array.isArray(_meal4.foods)) continue;
        if (_meal4._autoPreWorkout) continue;   // وجبة قبل التمرين تفضل خفيفة
        const _ids4 = _meal4.foods.map(function(x){ return (x.food && x.food.id) || ''; });
        const _opts = _plan4Slot(_meal4);
        for (var o = 0; o < _opts.length && dCals < _tgt * 0.97; o++){
          const _o = _opts[o];
          if (_ids4.indexOf(_o.id) !== -1) continue;
          // ممنوع التكديس: بروتين واحد بس دايماً. الكارب التاني مسموح بس لو اليوم ناقص أكتر من 10%.
          if (_o.cat === 'protein' && _hasCat4(_meal4, _o.cat)) continue;
          var _realN2 = meals.filter(function(mm){return mm && !mm._autoPreWorkout && ((mm.foods||[]).length>0);}).length;
          if (_o.cat === 'carb' && _hasCat4(_meal4, _o.cat) && (dCals >= _tgt * 0.90 || _realN2 <= 2)) continue;
          const _entry = { food: Object.assign({ unit:'جم', mealTypes:[] }, _o), grams:0, cals:0, pro:0, carb:0, fat:0 };
          // لازم يعدي قواعد الاقتران المصرية (بما فيها ممنوع رز في الفطار).
          const _namesNew = _meal4.foods.map(_efNameOf).concat(_efNameOf(_entry));
          if (!_efPairingKeep(_entry, _namesNew, _meal4)) continue;
          const _capO = _efPortionCap(_entry);
          let _gO = Math.min(_capO, Math.max(10, Math.round((_tgt - dCals) / _o.cal * 100)));
          _gO = Math.round(_gO / 5) * 5;
          if (_gO < 10) continue;
          _efSetGrams(_entry, _gO);
          _meal4.foods.push(_entry);
          _ids4.push(_o.id);
          dCals += Number(_entry.cals) || 0;
        }
      }
    }
    // [FIX-UNDERTARGET] لو لسه ناقص، مدّد الكميات الكثيفة قبل ما نعيد الحساب.
    try { _efStretchToTarget(plan); } catch(_stErr){ plan.stretchError = String((_stErr&&_stErr.message)||_stErr); }
    dCals = 0; dPro = 0; dCarb = 0; dFat = 0;
    for (var m3 = 0; m3 < meals.length; m3++){
      const _t3 = _efRecalcTotals(meals[m3]);
      dCals += _t3.cals; dPro += _t3.pro; dCarb += _t3.carb; dFat += _t3.fat;
    }
  }
  // والاتجاه التاني: لو اليوم زاد عن الهدف نقص من غير الخضار.
  // "لا أقل ولا أكتر" — لازم يشتغل في الاتجاهين.
  if (_tgt > 0 && dCals > _tgt * 1.03){
    let _g2 = 0;
    while (dCals > _tgt * 1.03 && _g2++ < 60){
      let _cut = false;
      for (var m5 = 0; m5 < meals.length; m5++){
        const _fs = (meals[m5] && meals[m5].foods) || [];
        for (var k5 = 0; k5 < _fs.length; k5++){
          if (dCals <= _tgt * 1.03) break;
          const f5 = _fs[k5];
          const c5 = _efCatOf(f5);
          if (c5 === 'veg' || c5 === 'veggie' || c5 === 'vegetable' || c5 === 'vegetables') continue;
          const _p5 = (f5.food && f5.food.cal != null) ? Number(f5.food.cal) : 0;
          const _cg = Number(f5.grams) || 0;
          if (!_p5 || _cg <= 15) continue;
          let _dg = Math.min(_cg - 15, Math.max(5, Math.round((dCals - _tgt) / _p5 * 100)));
          _dg = Math.round(_dg / 5) * 5;
          if (_dg < 5) continue;
          const _b5 = Number(f5.cals) || 0;
          _efSetGrams(f5, _cg - _dg);
          dCals -= _b5 - (Number(f5.cals) || 0);
          _cut = true;
        }
      }
      if (!_cut) break;
    }
    dCals = 0; dPro = 0; dCarb = 0; dFat = 0;
    for (var m6 = 0; m6 < meals.length; m6++){
      const _t6 = _efRecalcTotals(meals[m6]);
      dCals += _t6.cals; dPro += _t6.pro; dCarb += _t6.carb; dFat += _t6.fat;
    }
  }
  // تنظيف أخير للعيش
  // بلوك إقفال فجوة السعرات فوق ممكن يكون ضاف عيش بلدي لوجبة فيها عيش أبيض
  // فلازم نعدي تاني بعده مش قبله بس وإلا الباج يرجع في أهداف الزيادة
  try { _efRebalanceDay(plan); } catch(_re){ plan.rebalanceError = String((_re&&_re.message)||_re); }
  try { _efOwnerPost(plan); } catch(_oqErr){ plan.ownerPostError = String((_oqErr&&_oqErr.message)||_oqErr); }
  try { _efEnforceFatPairing(plan); } catch(_fpErr){ plan.fatPairError = String((_fpErr&&_fpErr.message)||_fpErr); }
  for (var m7 = 0; m7 < meals.length; m7++){ _efDedupeBread(meals[m7]); }
  // بوابة نهائية واحدة بعد كل التعديلات: حدود الحصة، دهون ديناميكية، سقوف اليوم والسعرات.
  try { _efEnforceOwnerServingLimits(plan); } catch(_os1){ plan.ownerServingError1=String((_os1&&_os1.message)||_os1); }
  try { _efSizeAddedFats(plan); } catch(_fe){ plan.fatSizeError = String((_fe&&_fe.message)||_fe); }
  try { _efEnforceOwnerServingLimits(plan); } catch(_os2){ plan.ownerServingError2=String((_os2&&_os2.message)||_os2); }
  try { _efEnforceDailyCaps(plan); } catch(_dcErr2){ plan.dailyCapError2 = String((_dcErr2&&_dcErr2.message)||_dcErr2); }
  try { _efHardCapMeals(plan); } catch(_hcErr){ plan.hardCapError = String((_hcErr&&_hcErr.message)||_hcErr); }
  try { _efCloseOwnerCalorieTolerance(plan); } catch(_ctErr){ plan.calorieToleranceError=String((_ctErr&&_ctErr.message)||_ctErr); }
  try { _efEnforceOwnerServingLimits(plan); } catch(_os3){ plan.ownerServingError3=String((_os3&&_os3.message)||_os3); }
  try { _efEnforceDailyCaps(plan); } catch(_dcErr3){ plan.dailyCapError3 = String((_dcErr3&&_dcErr3.message)||_dcErr3); }
  try { _efCloseOwnerCalorieTolerance(plan); } catch(_ctErr2){ plan.calorieToleranceError2=String((_ctErr2&&_ctErr2.message)||_ctErr2); }
  // أي post-processor سابق قد يزيل السلطة/الكارب أو يفتح فجوة. هذه هي
  // البوابة الأخيرة قبل إخراج الخطة: بنية الوجبة أولاً ثم إغلاق السعرات
  // مع الالتزام الصارم بسقف البروتين وحدود اليوم.
  try { _efEnsureMainMealStructure(plan); } catch(_msErr){ plan.mealStructureError=String((_msErr&&_msErr.message)||_msErr); }
  try { _efEnforceEggRange(plan); } catch(_egErr){ plan.eggRangeError=String((_egErr&&_egErr.message)||_egErr); }
  try { _efEnforceOwnerServingLimits(plan); _efEnforceDailyCaps(plan); } catch(_fcErr){ plan.finalCapsError=String((_fcErr&&_fcErr.message)||_fcErr); }
  try { _efFillTwoMealEggGap(plan); } catch(_pwErr){ plan.twoMealFillError=String((_pwErr&&_pwErr.message)||_pwErr); }
  try { _efFillRequestedCalorieFloor(plan); _efTrimDayToTolerance(plan); } catch(_ffErr){ plan.finalFillError=String((_ffErr&&_ffErr.message)||_ffErr); }
  try { _efEnforceOwnerServingLimits(plan); _efEnforceDailyCaps(plan); } catch(_fcErr2){ plan.finalCapsError2=String((_fcErr2&&_fcErr2.message)||_fcErr2); }
  // [FIX-EMPTY-MEAL] شيل أي وجبة فاضية أو 0 سعرة (زي سناك2 الفاضية في يوم التمرين).
  for (var _em = meals.length - 1; _em >= 0; _em--){
    var _emm = meals[_em];
    if (_emm && _emm._autoPreWorkout) continue;
    var _efs = (_emm && _emm.foods) || [];
    var _ecc = _efs.reduce(function(s,f){ return s + (Number(f.cals!=null?f.cals:f.calories)||0); }, 0);
    if (!_efs.length || _ecc <= 0) meals.splice(_em, 1);
  }
  dCals = 0; dPro = 0; dCarb = 0; dFat = 0;
  for (var m8 = 0; m8 < meals.length; m8++){
    const _t8 = _efRecalcTotals(meals[m8]);
    dCals += _t8.cals; dPro += _t8.pro; dCarb += _t8.carb; dFat += _t8.fat;
  }
  if (plan.totals && typeof plan.totals === 'object'){
    plan.totals.cals = Math.round(dCals); plan.totals.pro = Math.round(dPro); plan.totals.carb = Math.round(dCarb); plan.totals.fat = Math.round(dFat);
  }
  return plan;
}
function normalizeSearch(value){
  return String(value||'').toLowerCase().replace(/[\u064B-\u0652\u0670\u0640]/g,'')
    .replace(/[أإآ]/g,'ا').replace(/[ةه]/g,'ه').replace(/[يى]/g,'ي')
    .replace(/ؤ/g,'و').replace(/ئ/g,'ي').replace(/ء/g,'').replace(/\s+/g,' ').trim();
}
// Egyptian-first ordering (refined to the owner's canonical staples list):
//  - everyday Egyptian foods surface FIRST in the exact priority the owner gave
//  - uncommon/expensive items are NEVER hidden from the picker; they stay fully
//    searchable and are simply pushed to the very END of any list
//  - the automatic PLAN (الاقتراحات) still excludes them through the engine's own
//    affordability layer (module 23), so "hidden from suggestions, shown in
//    search, always last" is honoured end-to-end.
// egyIsRare mirrors module 23's excluded() set and is CATEGORY-AWARE so a short
// token like "مخ" only demotes offal (protein) and never "مخلل".
var EGY_COMMON_ORDER=[
  // كربوهيدرات
  'رز ابيض','رز بسمتي','رز بني','عيش بلدي','عيش اسمر','عيش ابيض','بطاطس مسلوقة','بطاطس مشوية','بطاطس بوريه','مكرونة','بطاطا مشوية','فول مدمس',
  // بروتين (التوكنز مطابقة لأسماء الكتالوج الفعلية: صدر/ورك مفرد)
  'صدر فراخ','ورك فراخ','جناح فراخ','كبدة فراخ','كبدة اسكندراني','قوانص فراخ','لحمه مسلوق','لحمه مشوي','لحمه كباب','كفتة مشوي','كفتة فراخ','ورك بط','صدر بط','بوري','بلطي','ماكريل','تونة','سردين','بيض','جبنة قريش','جبنة بيضاء','جبنة رومي','زبادي',
  // خضار مطبوخ
  'فاصوليا','لوبيه','بسلة','كوسة','خضار مشكل','عدس بجبه','باذنجان مشوي','شوربة عدس','ملوخية','شوربة فراخ','شوربة لحمة',
  // خضار
  'خس','طماطم','خيار','فلفل','جزر','كابوتشا','جرجير','فجل','ليمون',
  // فاكهة
  'تفاح','موز','برتقال','يوسفي','جوافة','مانجو','عنب','خوخ','برقوق','كمثرى','مشمش','فراولة','بطيخ','شمام','كنتالوب','رمان','تين','بلح','اناناس','كاكا','تمر',
  // سناكس ودهون
  'سوداني','شوكولاتة دارك','دارك','فشار','لب ابيض','لب قرع','لب سوري','زيت زيتون','طحينة','زيتون','مخلل',
  'سلطة'
];
var EGY_COMMON_ORDER_N=EGY_COMMON_ORDER.map(normalizeSearch);
function egyCommonRank(food){
  var name=normalizeSearch(String(food&&food.nameAr||''));
  for(var i=0;i<EGY_COMMON_ORDER_N.length;i++){ if(EGY_COMMON_ORDER_N[i] && name.indexOf(EGY_COMMON_ORDER_N[i])>-1) return i; }
  return 9999;
}
function egyIsRare(food){
  var nm=normalizeSearch(String(food&&food.nameAr||'')); var c=String(food&&food.cat||'');
  if(/افوكادو/.test(nm)) return true;
  if(/شوفان/.test(nm)) return true;
  if((c==='fat'||c==='snack') && /لوز|كاجو|عين جمل|بندق|فستق|بيكان|ماكاداميا|مكاديميا|صنوبر/.test(nm) && !/سوداني|طحينة|سمسم|لب /.test(nm)) return true;
  if(c==='dairy' && /حليب لوز|حليب كاجو|حليب شوفان/.test(nm)) return true;
  if(c==='protein' && /جمبري|سبيط|كاليماري|كابوريا|سلمون|رنجة|انشوجة|فسيخ|استاكوزا|جندوفل|بلح البحر|سلطعون|لوبستر|محار|كافيار|بطارخ/.test(nm)) return true;
  if(c==='protein' && /رومي|تركي|حمام|سمان|ارنب|طحال|مخ|كلاوي|كرشة|كوارع|عكاوي|جمل|لحمة راس/.test(nm)) return true;
  if(c==='veggie' && /بروكلي|فطر|مشروم|كينوا|كيل|هليون|خرشوف/.test(nm)) return true;
  return false;
}
function searchFoods(options){
  options=options||{}; const query=normalizeSearch(options.query), cat=String(options.category||'all');
  const diet=String(options.diet||'balanced'); const health=Array.isArray(options.health)?options.health:[];
  const words=query.split(' ').filter(Boolean); const catalog=(ctx().__EF_FOOD_CATALOG||[]).slice();
  const extras=[
    {id:'kbda_wnwans_frakh',nameAr:'كبد وقوانص فراخ',cat:'protein',cal:143,pro:22,carb:1,fat:5,healthyScore:8},
    {id:'kbda_baqary_esk',nameAr:'كبدة إسكندراني',cat:'protein',cal:191,pro:26,carb:5,fat:7,healthyScore:8}
  ];
  extras.forEach(function(x){if(!catalog.some(function(f){return f.id===x.id;}))catalog.push(x);});
  return catalog.filter(function(food){
    if(cat!=='all'&&food.cat!==cat)return false;
    if(food.cat==='fruit'&&!_efAllowedFruit(food))return false;
    if(food.allowedDiets&&food.allowedDiets.length&&food.allowedDiets.indexOf(diet)<0)return false;
    if((food.avoidHealth||[]).some(function(x){return health.indexOf(x)>-1;}))return false;
    if(!passesHealth(food, health))return false;   // الفلاتر العلاجية المصرية
    const hay=normalizeSearch((food.nameAr||'')+' '+(food.nameEn||'')+' '+(food.id||''));
    return words.every(function(word){return hay.indexOf(word)>-1||(word[0]==='ا'&&hay.indexOf(word.slice(1))>-1);});
  }).sort(function(a,b){
    var raA=egyIsRare(a)?1:0, raB=egyIsRare(b)?1:0;   // الغالي/النادر دايمًا في الآخر
    if(raA!==raB) return raA-raB;
    var ca=egyCommonRank(a), cb=egyCommonRank(b);      // الشائع المصري بترتيب المالك أولًا
    if(ca!==cb) return ca-cb;
    return (b.healthyScore||0)-(a.healthyScore||0)||(a.nameAr||'').localeCompare(b.nameAr||'','ar');
  }).slice(0,60);
}
function _efAllowedFruit(food){
  var n=normalizeSearch(String(food&&food.nameAr||''));
  var d=(typeof globalThis!=='undefined'&&globalThis.__EF_NOW instanceof Date)?globalThis.__EF_NOW:new Date();
  var month=d.getMonth()+1;
  var all=['موز','تفاح'];
  var summer=['بطيخ','مانجو','عنب','خوخ','مشمش','برقوق','تين','تين شوكي','شمام','كانتالوب','جوافة','بلح'];
  var winter=['برتقال','يوسفي','فراولة','رمان','جوافة','كاكا','كيوي'];
  var list=all.concat(month>=4&&month<=10?summer:winter).map(normalizeSearch);
  return list.some(function(x){return n===x||n.indexOf(x)>-1;});
}
// ── Egyptian therapeutic filters (الفلاتر العلاجية) ──
// Each condition maps to plain Arabic tokens of foods to AVOID. Tokens are
// normalized the same way food names are, then matched by substring, so a
// diabetic never gets sugar/high-GI carbs pushed, a gout patient never gets
// organ meats/sardines, a hypertensive never gets pickles/salted fish, etc.
// Conservative defaults: they only shape the AUTO plan and the picker filter.
var EGY_HEALTH_AVOID_RAW = {
  diabetes:    ['سكر','عسل','مربى','دبس','قصب','تمر','بلح','مانجو','بطيخ','عصير','شربات','كنافة','بسبوسة','حلاوة','كورن فليكس','رز ابيض','عيش ابيض'],
  insulin:     ['سكر','عسل','مربى','دبس','قصب','تمر','بلح','عصير','كنافة','بسبوسة','حلاوة','رز ابيض','عيش ابيض'],
  bp:          ['مخلل','رنجة','فسيخ','ملوحة','لانشون','سجق','بسطرمة','بيكون','جبنة رومي','شيبسي','صويا','مكسرات مملحة'],
  cholesterol: ['كبد','كلاوي','كوارع','ممبار','طحال','سمنة','زبدة','قشطة','كريمة','مقلي','مقلية','لانشون','سجق','بسطرمة','بيكون'],
  kidney:      ['مخلل','رنجة','فسيخ','لانشون','سجق','بسطرمة','مكسرات','شوكولاتة','موز','بلح','تمر','جبنة رومي'],
  gerd:        ['مقلي','مقلية','شطة','فلفل حار','صلصة طماطم','ليمون','برتقال','جريب فروت','قهوة','نعناع','شوكولاتة','مشروب غازي'],
  gout:        ['كبد','كلاوي','كوارع','ممبار','طحال','سردين','انشوجة','رنجة','جمبري','استاكوزا','سبيط','كابوريا','مرقة لحمة'],
  ibs:         ['بصل','ثوم','فول','عدس','حمص','فاصوليا','لوبيا','تفاح','بطيخ','كمثرى','كرنب','قرنبيط','بروكلي','مشروب غازي']
};
var EGY_HEALTH_AVOID = (function(){
  var out = Object.create(null);
  Object.keys(EGY_HEALTH_AVOID_RAW).forEach(function(k){ out[k] = EGY_HEALTH_AVOID_RAW[k].map(normalizeSearch); });
  return out;
})();
function passesHealth(food, health){
  // القواعد الصحية أصبحت لتقليل الحصة لا لمنع الطعام المسموح منعًا مطلقًا.
  return true;
}
function _efApplyHealthPortionAdjustments(plan){
  var health=(plan&&plan._healthConditions)||[];if(!Array.isArray(health)||!health.length)return;
  for(var m=0;m<(plan.meals||[]).length;m++)for(var i=0;i<((plan.meals[m]&&plan.meals[m].foods)||[]).length;i++){
    var f=plan.meals[m].foods[i];if(f._healthAdjusted)continue;
    var nm=normalizeSearch(_efNameOf(f)),matched=false;
    for(var h=0;h<health.length&&!matched;h++){var toks=EGY_HEALTH_AVOID[health[h]]||[];for(var t=0;t<toks.length;t++)if(toks[t]&&nm.indexOf(toks[t])>-1){matched=true;break;}}
    if(!matched)continue;
    var cur=Number(f.grams)||0,floor=50;
    if(_efCatOf(f)==='egg'||/(^|\s)بيض(\s|$)/.test(_efNameOf(f)))floor=100;
    if(/طحينة|طحينه/.test(_efNameOf(f)))floor=20;
    if(_efIsVegF(f))floor=Math.min(cur,40);
    var next=Math.max(floor,Math.round(cur*.75/5)*5);
    if(next<cur)_efSetGramsFine(f,next);
    f._healthAdjusted=true;
  }
  for(var j=0;j<(plan.meals||[]).length;j++)_efRecalcTotals(plan.meals[j]);
}
// ── Fasting / Ramadan meal scheduler (وضع الصيام/رمضان) ──
// Relabels/re-times the engine's meals WITHOUT touching their food or macros.
// ── Automatic Hijri-date detection (tabular Islamic calendar) ──
// Converts today's Gregorian date to the Hijri calendar so the app knows when
// it is Ramadan WITHOUT any manual switch or network call. Tabular civil
// algorithm; may differ from the official moon sighting by ~1 day, which is
// acceptable for switching the meal-schedule view.
function _efGregToHijri(gy, gm, gd){
  var a = Math.floor((14 - gm) / 12);
  var y = gy + 4800 - a;
  var m = gm + 12 * a - 3;
  var jd = gd + Math.floor((153 * m + 2) / 5) + 365 * y + Math.floor(y / 4)
         - Math.floor(y / 100) + Math.floor(y / 400) - 32045;
  var l = jd - 1948440 + 10632;
  var n = Math.floor((l - 1) / 10631);
  l = l - 10631 * n + 354;
  var j = Math.floor((10985 - l) / 5316) * Math.floor((50 * l) / 17719)
        + Math.floor(l / 5670) * Math.floor((43 * l) / 15238);
  l = l - Math.floor((30 - j) / 15) * Math.floor((17719 * j) / 50)
        - Math.floor(j / 16) * Math.floor((15238 * j) / 43) + 29;
  var hm = Math.floor((24 * l) / 709);
  var hd = l - Math.floor((709 * hm) / 24);
  var hy = 30 * n + j - 30;
  return { y: hy, m: hm, d: hd };
}
function _efIsRamadanNow(){
  try {
    var d = (typeof globalThis !== 'undefined' && globalThis.__EF_NOW instanceof Date)
      ? globalThis.__EF_NOW : new Date();
    return _efGregToHijri(d.getFullYear(), d.getMonth() + 1, d.getDate()).m === 9;
  } catch(e){ return false; }
}
function applyMealSchedule(plan, mode){
  if(!plan || !Array.isArray(plan.meals) || !plan.meals.length) return plan;
  var meals = plan.meals; var n = meals.length;
  function relabel(i, label, desc){ meals[i] = Object.assign({}, meals[i], { label: label, description: desc }); }
  if(mode === 'ramadan'){
    for(var i=0;i<n;i++){
      if(i===0) relabel(i,'الإفطار (بعد المغرب)','ابدأ ب3 تمرات ومياه أو شوربة خفيفة وبعد صلاة المغرب كمل الوجبة الرئيسية');
      else if(i===n-1) relabel(i,'السحور (قبل الفجر)','ركز على بروتين + كارب بطيء الهضم عشان الطاقة تفضل معاك طول نهار الصيام');
      else if(String(meals[i].slotKey)==='snack' || /سناك/.test(String(meals[i].label||''))) relabel(i,'تحلية/سناك بعد الإفطار','خفيفة ويفضل بعد الوجبة الرئيسية بساعة');
      else relabel(i,'وجبة بين الإفطار والسحور',(meals[i].description||''));
    }
    plan.scheduleNote = 'وضع رمضان: وجباتك موزعة بين الإفطار والسحور نفس السعرات والماكروز اللي المحرك حسبها بالظبط';
  } else if(mode === 'if16'){
    var startH = 12, span = 8, step = n>1 ? Math.max(1, Math.floor(span/(n-1))) : 0;
    for(var j=0;j<n;j++){
      var hr = startH + (n>1 ? j*step : 0); var ampm = hr>=12 ? 'م' : 'ص'; var h12 = ((hr+11)%12)+1; var t = h12+' '+ampm;
      if(j===0) relabel(j,'أول وجبة فطر الصيام ('+t+')','افتح صيامك بوجبة متوازنة بروتين + كارب');
      else if(j===n-1) relabel(j,'آخر وجبة قبل الصيام ('+t+')','آخر أكل قبل ما تقفل نافذة الأكل');
      else relabel(j,'وجبة ('+t+')',(meals[j].description||'داخل نافذة الأكل'));
    }
    plan.scheduleNote = 'صيام متقطع 16:8 نافذة الأكل ~8 ساعات (مثال 12 الظهر ← 8 المساء). نفس السعرات والماكروز';
  }
  return plan;
}
function foodsByIds(ids){
  const wanted=new Set((Array.isArray(ids)?ids:[]).map(String));
  return (ctx().__EF_FOOD_CATALOG||[]).filter(function(food){return wanted.has(String(food.id));});
}
module.exports = { computeTargets:computeTargets, computeMealPlan:computeMealPlan, searchFoods:searchFoods, foodsByIds:foodsByIds, assertProfile:assertProfile, assertTargets:assertTargets, applyAvailableFoods:applyAvailableFoods, _buildContext:buildContext };
