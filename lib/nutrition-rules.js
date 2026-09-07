'use strict';
// =============================================================================
// lib/nutrition-rules.js
// العقل الواحد لقواعد التغذية — مصدر حقيقة واحد لكل قاعدة أكل.
// بيشتغل على شكل الخطة الحقيقي: plan.meals[].foods[] = { food:{id,nameAr,cat,...}, grams, cals, ... }
//
// فيه دالتين أساسيتين:
//   validate(plan)  → قائمة مخالفات [{code, meal, msg}] (للاختبارات والتشخيص)
//   enforce(plan)   → يصحّح المخالفات ويرجّع { plan, fixes:[...] } (متكرّر بأمان/idempotent)
// =============================================================================

const DB = require('./egyptian-food-db');
const L = DB.DAILY_LIMITS;

// ---------- مساعدات استخراج ----------
function nameOf(f) {
  const food = (f && f.food) ? f.food : f;
  return String((food && (food.nameAr || food.name)) || '');
}
function catOf(f) {
  const food = (f && f.food) ? f.food : f;
  return String((food && food.cat) || '');
}
function idOf(f) {
  const food = (f && f.food) ? f.food : f;
  return String((food && food.id) || '');
}
function gramsOf(f) { return Number((f && f.grams) || 0) || 0; }
function calsOf(f) { return Number((f && f.cals) || 0) || 0; }
function foodsOf(meal) { return (meal && Array.isArray(meal.foods)) ? meal.foods : []; }

// ---------- مصنّفات العناصر (بالاسم + الفئة) ----------
function isRice(f) { return /(?:^|\s)رز|أرز|ارز/.test(nameOf(f)); }
function isBread(f) { return /عيش|توست|رغيف|خبز/.test(nameOf(f)); }
function isMacarona(f) { return /مكرونة|مكرونه/.test(nameOf(f)); }
function isTuna(f) { return /تونة|تونه/.test(nameOf(f)); }
function isYogurt(f) { return /زبادي/.test(nameOf(f)); }
function isFish(f) { return catOf(f) === 'fish' || /سمك|تونة|ماكريل|بلطي|بوري|سردين/.test(nameOf(f)); }
function isCookedVeg(f) { return catOf(f) === 'cooked_veg'; }
function isSoup(f) { return catOf(f) === 'soup' || /شوربة/.test(nameOf(f)); }
function isPotato(f) { return /بطاطس|بطاطا/.test(nameOf(f)); }
function isSweetPotato(f) { return /بطاطا/.test(nameOf(f)) && !/بطاطس/.test(nameOf(f)); }
function isSaladVeg(f) { return catOf(f) === 'salad_veg'; }
function isOats(f) { return /شوفان|oats|oatmeal/i.test(nameOf(f) + ' ' + idOf(f)); }
function isCoffee(f) { return /قهوة|coffee/i.test(nameOf(f) + ' ' + idOf(f)); }
function isRawSaladVeg(f) {
  const c=catOf(f), n=nameOf(f);
  if (isCookedVeg(f) || isSoup(f) || /مطبوخ|مسلوق|مشوي|مخلل/.test(n)) return false;
  return c === 'salad_veg' || /^(veg|veggie|vegetable|vegetables)$/.test(c) && /طماطم|خيار|فلفل|جزر|خس|جرجير|بصل|فجل|كرنب|كابوتشا/.test(n);
}
function isCookedVegBannedProtein(f) {
  return isFish(f) || /كفتة|كبدة|كبد وقوانص|قوانص/.test(nameOf(f));
}
function sweetPotatoInSeason(now) {
  const m=(now instanceof Date?now:new Date()).getMonth()+1;
  return m>=8 || m===1;
}
function isPreEnergy(f, now) {
  const n=nameOf(f);
  if (/بطاطا/.test(n)) return sweetPotatoInSeason(now);
  return /موز|تفاح|تمر|شوكولاتة (?:دارك|داكنة)/.test(n);
}
function makeEntry(base, grams) {
  const f={food:Object.assign({},base),grams:0,cals:0,pro:0,carb:0,fat:0};
  setGramsSafe(f,grams); return f;
}
function canonicalizeSalad(meal, variant, fixes, force) {
  const current=foodsOf(meal), raw=current.filter(isRawSaladVeg);
  if (!raw.length && !force) return;
  const forms=[[0,1,2],[0,1,3],[0,1,4]];
  const idx=Math.abs(Math.round(Number(variant)||0))%forms.length;
  const unique=[];
  raw.forEach(function(f){if(!unique.some(function(x){return normalizedName(x)===normalizedName(f);}))unique.push(f);});
  const chosenEntries=unique.slice(0,3);
  forms[idx].map(i=>DB.SALAD_ITEMS[i]).forEach(function(base){
    if(chosenEntries.length<3&&!chosenEntries.some(function(x){return normalizedName(x)===normalizedName(base);})) chosenEntries.push(makeEntry(base,[70,60,50][chosenEntries.length]));
  });
  meal.foods=current.filter(f=>!isRawSaladVeg(f));
  chosenEntries.forEach(function(entry,i){if(entry.food){setGramsSafe(entry,[70,60,50][i]);meal.foods.push(entry);}else meal.foods.push(makeEntry(entry,[70,60,50][i]));});
  const chosen=chosenEntries;
  if (raw.length !== 3 || raw.some((f,i)=>!chosen[i] || normalizedName(f)!==normalizedName(chosen[i])))
    fixes.push({code:'salad_exactly_three',meal:String(meal.label||slotOf(meal)),why:'طبق السلطة موحد من 3 مكونات نيئة'});
}
function isEgg(f) { if (catOf(f) === 'egg') return true; const n = nameOf(f); return /(^|\s)بيض(\s|$)/.test(n) && !/جبن/.test(n); }
function isCheese(f) { return catOf(f) === 'cheese' || /جبن/.test(nameOf(f)); }
function isFoul(f) { return /فول/.test(nameOf(f)); }
function isComplement(f) {
  const food = (f && f.food) ? f.food : f;
  if (food && food.complement) return true;
  return /زيت|زبدة|طحينة|زيتون/.test(nameOf(f));
}
function normalizedName(f) {
  return nameOf(f).replace(/[\u064B-\u0652\u0670\u0640]/g, '').replace(/[أإآ]/g, 'ا')
    .replace(/[ةه]/g, 'ه').replace(/\s+/g, ' ').trim();
}
function starchKind(f) {
  if (isBread(f) || /رايس كيك/.test(nameOf(f))) return 'bread';
  if (isRice(f)) return 'rice';
  if (isMacarona(f)) return 'pasta';
  if (isPotato(f)) return 'potato';
  return null;
}
function allowedFruitNames(now) {
  const month = (now instanceof Date ? now : new Date()).getMonth() + 1;
  const seasonal = month >= 4 && month <= 10 ? DB.FRUITS_SUMMER : DB.FRUITS_WINTER;
  return DB.FRUITS_YEAR_ROUND.concat(seasonal);
}
function isAllowedFruit(f, now) {
  if (catOf(f) !== 'fruit') return true;
  const n = normalizedName(f);
  return allowedFruitNames(now).some(function (x) {
    const k = normalizedName({ nameAr: x });
    return n === k || n.indexOf(k) >= 0;
  });
}
function validFatBase(fat, foods) {
  const n = nameOf(fat);
  if (/زيت زيتون|^زيت$/.test(n)) return foods.some(function (x) {
    const v = nameOf(x); return /سلطة|طماطم|خيار|فلفل|جزر|خس|جرجير/.test(v) || (/فول/.test(v) && !/سوداني/.test(v)) || (/جبن/.test(v) && /بيضا|بيضاء|قريش|رودس/.test(v)) || /كبدة إسكندراني|كبد وقوانص/.test(v);
  });
  if (/زبدة|زبده|سمنة|سمنه/.test(n)) return foods.some(function (x) { return /فول مدمس|بيض مقلي/.test(nameOf(x)); });
  return true;
}

// ---------- مساعدات الوجبات ----------
function slotOf(meal) { return String((meal && meal.slotKey) || ''); }
function isBreakfast(meal) { return slotOf(meal) === 'breakfast' || /فطار|فطور|إفطار/.test(slotOf(meal) + ' ' + String((meal && meal.label) || '')); }
function isLunch(meal) { return slotOf(meal) === 'lunch' || /غدا/.test(String((meal && meal.label) || '')); }
function isDinner(meal) { return slotOf(meal) === 'dinner' || /عشا/.test(String((meal && meal.label) || '')); }
function isSnack(meal) { return slotOf(meal) === 'snack' || /سناك|تحلية/.test(slotOf(meal) + ' ' + String((meal && meal.label) || '')); }
function isPre(meal) { return slotOf(meal) === 'pre' || Boolean(meal && meal._autoPreWorkout) || /قبل التمرين/.test(String((meal && meal.label) || '')); }
function isMainMeal(meal) { return isBreakfast(meal) || isLunch(meal) || isDinner(meal); }

function mealCals(meal) { return foodsOf(meal).reduce(function (s, f) { return s + calsOf(f); }, 0); }
function dayCals(plan) { return (plan.meals || []).reduce(function (s, m) { return s + mealCals(m); }, 0); }

// فئات البروتين المتميّزة في الفطار (لتطبيق قاعدة التوليفات)
function breakfastProteinKinds(meal) {
  const kinds = {};
  foodsOf(meal).forEach(function (f) {
    if (isEgg(f)) kinds.egg = true;
    else if (isCheese(f)) kinds.cheese = true;
    else if (isFoul(f)) kinds.legume_cooked = true;
  });
  return Object.keys(kinds);
}

// =============================================================================
// validate(plan) → [{ code, meal, msg }]
// =============================================================================
function validate(plan) {
  const v = [];
  const meals = (plan && plan.meals) || [];

  // عدد الوجبات اللي فيها سعرات (لقاعدة الـ 40%)
  const nonEmpty = meals.filter(function (m) { return mealCals(m) > 0 && !isPre(m); });
  const total = dayCals(plan);

  let tunaTotal = 0, yogurtTotal = 0, eggTotal = 0, olivesTotal = 0;

  meals.forEach(function (meal) {
    const label = String(meal.label || slotOf(meal));
    const foods = foodsOf(meal);
    const hasFish = foods.some(isFish);
    const hasCookedVeg = foods.some(isCookedVeg);
    const hasSoup = foods.some(isSoup);
    const hasPotato = foods.some(isPotato);
    const hasSalad = foods.some(isSaladVeg);
    const hasRice = foods.some(isRice);
    const hasTuna = foods.some(isTuna);
    const rawSalad = foods.filter(isRawSaladVeg);
    const bannedCookedProtein = foods.some(isCookedVegBannedProtein);
    if (foods.some(isOats)) v.push({code:'oats_forbidden',meal:label,msg:'الشوفان ممنوع في النظام'});
    if (isPre(meal)) {
      const coffeeCount=foods.filter(isCoffee).length;
      const energy=foods.filter(f=>isPreEnergy(f));
      if (coffeeCount!==1 || energy.length!==1 || foods.length!==2)
        v.push({code:'preworkout_pair_required',meal:label,msg:'قبل التمرين = قهوة + مصدر طاقة واحد'});
    }
    if (isMainMeal(meal) && !hasCookedVeg && !hasSoup && rawSalad.length!==3)
      v.push({code:'salad_exactly_three',meal:label,msg:'طبق السلطة لازم يكون 3 عناصر نيئة'});

    const seenItems = {};
    foods.forEach(function (f) {
      const key = idOf(f) || normalizedName(f);
      if (seenItems[key]) v.push({ code: 'duplicate_food', meal: label, msg: 'الصنف مكرر داخل الوجبة: ' + nameOf(f) });
      seenItems[key] = true;
      if (isSweetPotato(f) && !isPre(meal) && !isSnack(meal))
        v.push({ code: 'sweet_potato_slot', meal: label, msg: 'البطاطا مسموحة قبل التمرين أو كسناك فقط' });
      if (!isAllowedFruit(f)) v.push({ code: 'fruit_not_allowed', meal: label, msg: 'فاكهة خارج القائمة الموسمية: ' + nameOf(f) });
      if (!validFatBase(f, foods)) v.push({ code: 'orphan_added_fat', meal: label, msg: 'زيت/زبدة بدون العنصر المرتبط' });
      if (/زيتون مخلل/.test(nameOf(f))) olivesTotal++;
    });
    const starches = foods.filter(function(f){return starchKind(f);});
    if (isBreakfast(meal) && starches.length > 1)
      v.push({ code: 'breakfast_one_starch', meal: label, msg: 'الفطار يحتوي أكثر من مصدر نشويات' });
    if (starches.some(function(x){return starchKind(x)==='bread';}) && starches.some(function (x) { return starchKind(x) !== 'bread'; }))
      v.push({ code: 'bread_starch_conflict', meal: label, msg: 'العيش لا يجتمع مع رز/بطاطس/مكرونة' });
    if (starches.some(function(x){return starchKind(x)==='rice';}) && starches.some(function(x){return starchKind(x)==='pasta';}))
      v.push({ code: 'rice_pasta_conflict', meal: label, msg: 'الرز لا يجتمع مع المكرونة' });

    // 1) مفيش رز في الفطار أبدًا
    if (isBreakfast(meal) && hasRice) {
      v.push({ code: 'no_rice_breakfast', meal: label, msg: 'رز في الفطار — ممنوع' });
    }
    // 2) خضار مطبوخ XOR سلطة في نفس الوجبة
    if (hasCookedVeg && hasSalad) {
      v.push({ code: 'cookedveg_xor_salad', meal: label, msg: 'خضار مطبوخ + سلطة في نفس الوجبة' });
    }
    // 3) مفيش خضار مطبوخ/شوربة/بطاطس مع السمك/التونة
    if (bannedCookedProtein && (hasCookedVeg || hasSoup)) {
      v.push({ code: 'no_cookedveg_with_banned_protein', meal: label, msg: 'الخضار المطبوخ/الشوربة ممنوعان مع السمك والتونة والكفتة والكبدة' });
    }
    if (hasFish && hasPotato) {
      v.push({ code: 'no_potato_with_fish', meal: label, msg: 'البطاطس لا تجتمع مع السمك/التونة' });
    }
    // 4) مفيش رز مع التونة
    if (hasTuna && hasRice) {
      v.push({ code: 'no_rice_with_tuna', meal: label, msg: 'رز مع التونة' });
    }
    // 7) الفطار: حد أقصى بروتينين + ممنوع جبنة+فول+بيض مع بعض
    if (isBreakfast(meal)) {
      const kinds = breakfastProteinKinds(meal);
      if (kinds.length > DB.BREAKFAST_MIX_MAX_PROTEINS) {
        v.push({ code: 'breakfast_too_many_proteins', meal: label, msg: 'أكتر من بروتينين في الفطار (' + kinds.join('+') + ')' });
      }
    }
    // 8) سقف صريح: وجبتان = 50%، وأكثر من وجبتين = 40%.
    if (isMainMeal(meal) && total > 0) {
      const cap=nonEmpty.length<=2?0.50:0.40;
      const share=mealCals(meal)/total;
      if (share > cap + 0.001)
        v.push({code:'meal_share_too_high',meal:label,msg:'الوجبة بتاخد '+Math.round(share*100)+'% من اليوم (الحد '+Math.round(cap*100)+'%)'});
    }

    foods.forEach(function (f) {
      if (isTuna(f)) tunaTotal += gramsOf(f);
      if (isYogurt(f)) yogurtTotal += gramsOf(f);
      if (isEgg(f)) eggTotal += gramsOf(f);
    });
  });

  // 5) تونة ≤ 300 جم/يوم
  if (tunaTotal > L.tunaMaxGrams) {
    v.push({ code: 'tuna_over_limit', meal: 'day', msg: 'إجمالي التونة ' + Math.round(tunaTotal) + 'جم > ' + L.tunaMaxGrams + 'جم' });
  }
  // 6) زبادي ≤ 200 جم/يوم
  if (yogurtTotal > L.yogurtMaxGrams) {
    v.push({ code: 'yogurt_over_limit', meal: 'day', msg: 'إجمالي الزبادي ' + Math.round(yogurtTotal) + 'جم > ' + L.yogurtMaxGrams + 'جم' });
  }
  if (eggTotal > 0 && eggTotal < L.eggMinGramsWhenUsed)
    v.push({ code: 'egg_under_daily_min', meal: 'day', msg: 'عند اختيار البيض لا يقل إجمالي اليوم عن 100جم' });
  if (eggTotal > L.eggMaxGrams)
    v.push({ code: 'egg_over_daily_max', meal: 'day', msg: 'إجمالي البيض لا يزيد عن 300جم' });
  if (olivesTotal > 1) v.push({ code: 'olives_daily_limit', meal: 'day', msg: 'الزيتون المخلل يظهر مرة واحدة فقط في اليوم' });
  const target = Number(plan && plan.targetCals) || 0;
  if (target > 0 && (total < target - 100 || total > target + 50))
    v.push({ code: 'day_calorie_tolerance', meal: 'day', msg: 'سعرات اليوم خارج المدى المسموح (-100/+50)' });

  // 9) العشا = تكرار أخف — مفيش عنصر جديد ماظهرش في الفطار/الغدا
  const earlierNames = {};
  meals.forEach(function (m) {
    if (isBreakfast(m) || isLunch(m)) foodsOf(m).forEach(function (f) { earlierNames[nameOf(f)] = true; });
  });
  meals.forEach(function (m) {
    if (!isDinner(m)) return;
    foodsOf(m).forEach(function (f) {
      const nm = nameOf(f);
      // السلطة/الخضار عنصر بنيوي مطلوب في العشاء، وليست «صنفًا جديدًا» ممنوعًا.
      const light = isYogurt(f) || catOf(f) === 'fruit' || isComplement(f) || isSaladVeg(f) || isCookedVeg(f) || /طماطم|خيار|خس|جرجير|فلفل أخضر|بصل/.test(nm) || !!starchKind(f);
      if (!light && !earlierNames[nm]) {
        v.push({ code: 'dinner_new_item', meal: String(m.label || 'dinner'), msg: 'عنصر جديد في العشا (' + nm + ') ماظهرش في الفطار/الغدا' });
      }
    });
  });

  return v;
}

// =============================================================================
// enforce(plan) → { plan, fixes } — يصحّح المخالفات بأمان (idempotent)
// التصحيح = إزالة العنصر المخالف (الأقل أولوية) مع تسجيل السبب.
// المحرك بيعيد موازنة السعرات بعدكده؛ هنا الأولوية للقاعدة.
// =============================================================================
function removeFrom(meal, pred, fixes, code, why) {
  const foods = foodsOf(meal);
  const kept = [];
  foods.forEach(function (f) {
    if (pred(f)) { fixes.push({ code: code, meal: String(meal.label || slotOf(meal)), removed: nameOf(f), why: why }); }
    else kept.push(f);
  });
  meal.foods = kept;
}

function enforce(plan) {
  const fixes = [];
  const meals = (plan && plan.meals) || [];

  meals.forEach(function (meal) {
    let foods = foodsOf(meal);
    // الصنف الواحد يظهر مرة واحدة. ندمج الكمية بدل الاحتفاظ بسطرين.
    const unique = [], byKey = {};
    foods.forEach(function (f) {
      const key = idOf(f) || normalizedName(f);
      if (!byKey[key]) { byKey[key] = f; unique.push(f); return; }
      const keep = byKey[key], merged = gramsOf(keep) + gramsOf(f);
      setGramsSafe(keep, merged);
      fixes.push({ code: 'duplicate_food', meal: String(meal.label || slotOf(meal)), removed: nameOf(f), why: 'دمجنا الصنف المكرر في كمية واحدة' });
    });
    meal.foods = unique;
    foods = foodsOf(meal);

    removeFrom(meal, function (f) { return isSweetPotato(f) && !isPre(meal) && !isSnack(meal); },
      fixes, 'sweet_potato_slot', 'البطاطا قبل التمرين أو كسناك فقط');
    removeFrom(meal, function (f) { return !isAllowedFruit(f); },
      fixes, 'fruit_not_allowed', 'فاكهة خارج القائمة الموسمية المعتمدة');
    removeFrom(meal, isOats, fixes, 'oats_forbidden', 'الشوفان ممنوع تمامًا');

    if (isPre(meal)) {
      let preFoods=foodsOf(meal);
      let energy=preFoods.filter(function(f){return isPreEnergy(f);});
      let chosen=energy[0];
      if (!chosen) chosen=makeEntry(DB.PRE_WORKOUT_ADDONS.find(function(x){return x.id==='banana';}),100);
      let coffee=preFoods.find(isCoffee);
      if (!coffee) coffee=makeEntry(DB.PRE_WORKOUT_BASE,200);
      meal.foods=[coffee,chosen];
      if (preFoods.length!==2 || energy.length!==1 || !preFoods.some(isCoffee))
        fixes.push({code:'preworkout_pair_required',meal:String(meal.label||slotOf(meal)),why:'قهوة + مصدر طاقة واحد فقط'});
    }

    // مصدر كربوهيدرات واحد فقط. خارج الفطار: رز ثم عيش ثم بطاطس ثم مكرونة.
    const sf=foodsOf(meal).filter(function(f){return starchKind(f);});
    if (sf.length>1) {
      const rank=isBreakfast(meal)?{bread:0,potato:1,pasta:2,rice:3}:{rice:0,bread:1,potato:2,pasta:3};
      sf.sort(function(a,b){return rank[starchKind(a)]-rank[starchKind(b)];});
      const keep=sf[0], removed=sf.slice(1);
      absorbCalories(keep,removed);
      removeFrom(meal,function(f){return starchKind(f)&&f!==keep;},fixes,'one_starch_per_meal','مصدر كربوهيدرات واحد فقط في الوجبة');
    }
    removeFrom(meal, function (f) { return !validFatBase(f, foodsOf(meal)); }, fixes, 'orphan_added_fat', 'الإضافة الدهنية لازم ترتبط بعنصرها');
    // 1) رز في الفطار → شيله
    if (isBreakfast(meal)) removeFrom(meal, isRice, fixes, 'no_rice_breakfast', 'مفيش رز في الفطار');

    // 4) رز مع تونة → شيل الرز (التونة ترتبط بالعيش لو محتاجة كارب)
    if (foods.some(isTuna)) removeFrom(meal, isRice, fixes, 'no_rice_with_tuna', 'مفيش رز مع التونة');

    // الخضار المطبوخ/الشوربة ممنوعان مع السمك والتونة والكفتة وكل الكبدة/القوانص.
    if (foodsOf(meal).some(isCookedVegBannedProtein)) {
      removeFrom(meal,function(f){return isCookedVeg(f)||isSoup(f);},fixes,'no_cookedveg_with_banned_protein','الخضار المطبوخ ممنوع مع نوع البروتين ده');
    }
    if (foodsOf(meal).some(isFish))
      removeFrom(meal,isPotato,fixes,'no_potato_with_fish','البطاطس لا تجتمع مع السمك/التونة');

    // 2) خضار مطبوخ + سلطة → سيب الخضار المطبوخ وشيل السلطة (المطبوخ أولوية في وجبة رئيسية)
    if (foodsOf(meal).some(isCookedVeg) && foodsOf(meal).some(isSaladVeg)) {
      removeFrom(meal, isSaladVeg, fixes, 'cookedveg_xor_salad', 'خضار مطبوخ أو سلطة — مش الاتنين');
    }

    // 7) الفطار: أكتر من بروتينين → سيب أول اتنين وشيل الزايد
    if (isBreakfast(meal)) {
      const seenKinds = {};
      const kept = [];
      foodsOf(meal).forEach(function (f) {
        let kind = null;
        if (isEgg(f)) kind = 'egg'; else if (isCheese(f)) kind = 'cheese'; else if (isFoul(f)) kind = 'legume_cooked';
        if (kind) {
          const distinct = Object.keys(seenKinds).length;
          if (!seenKinds[kind] && distinct >= DB.BREAKFAST_MIX_MAX_PROTEINS) {
            fixes.push({ code: 'breakfast_too_many_proteins', meal: String(meal.label || 'breakfast'), removed: nameOf(f), why: 'حد أقصى بروتينين في الفطار' });
            return;
          }
          seenKinds[kind] = true;
        }
        kept.push(f);
      });
      meal.foods = kept;
    }
    const noCooked=!foodsOf(meal).some(function(f){return isCookedVeg(f)||isSoup(f);});
    const forceSalad=isMainMeal(meal)&&noCooked&&String(plan&&plan._dietKey||'')!=='carnivore';
    canonicalizeSalad(meal,(Number(plan&&plan._saladVariant)||0)+(isLunch(meal)?1:isDinner(meal)?2:0),fixes,forceSalad);
  });

  // 5/6) سقوف التونة والزبادي على مستوى اليوم — قلّل الجرامات للسقف
function capNutrient(pred, maxGrams, code, why) {
    let running = 0;
    meals.forEach(function (meal) {
      foodsOf(meal).forEach(function (f) {
        if (!pred(f)) return;
        const g = gramsOf(f);
        if (running + g <= maxGrams) { running += g; return; }
        const allow = Math.max(0, maxGrams - running);
        running = maxGrams;
        if (allow < g) {
          const per = g > 0 ? (f.food && f.food.per100) : null;
          setGramsSafe(f, allow);
          fixes.push({ code: code, meal: String(meal.label || slotOf(meal)), item: nameOf(f), newGrams: allow, why: why });
        }
      });
    });
  }
  capNutrient(isTuna, L.tunaMaxGrams, 'tuna_over_limit', 'تونة ≤ 300جم/يوم');
  capNutrient(isYogurt, L.yogurtMaxGrams, 'yogurt_over_limit', 'زبادي ≤ 200جم/يوم');
  capNutrient(isEgg, L.eggMaxGrams, 'egg_over_daily_max', 'بيض ≤ 300جم/يوم');
  let eggEntries = [];
  meals.forEach(function (meal) { foodsOf(meal).forEach(function (f) { if (isEgg(f)) eggEntries.push(f); }); });
  const eggUsed = eggEntries.reduce(function (s, f) { return s + gramsOf(f); }, 0);
  if (eggUsed > 0 && eggUsed < L.eggMinGramsWhenUsed) {
    const firstEgg = eggEntries[0];
    setGramsSafe(firstEgg, gramsOf(firstEgg) + (L.eggMinGramsWhenUsed - eggUsed));
    fixes.push({ code: 'egg_under_daily_min', meal: 'day', item: nameOf(firstEgg), newGrams: gramsOf(firstEgg), why: 'رفع إجمالي البيض المختار إلى 100جم' });
  }

  let oliveSeen = false;
  meals.forEach(function (meal) {
    removeFrom(meal, function (f) {
      if (!/زيتون مخلل/.test(nameOf(f))) return false;
      if (!oliveSeen) { oliveSeen = true; return false; }
      return true;
    }, fixes, 'olives_daily_limit', 'الزيتون المخلل مرة واحدة في اليوم');
  });

  // 9) العشا: شيل أي عنصر جديد (مش خفيف/ماظهرش قبل كده)
  const earlierNames = {};
  meals.forEach(function (m) {
    if (isBreakfast(m) || isLunch(m)) foodsOf(m).forEach(function (f) { earlierNames[nameOf(f)] = true; });
  });
  meals.forEach(function (m) {
    if (!isDinner(m)) return;
    removeFrom(m, function (f) {
      const light = isYogurt(f) || catOf(f) === 'fruit' || isComplement(f) || isSaladVeg(f) || isCookedVeg(f) || /طماطم|خيار|خس|جرجير|فلفل أخضر|بصل/.test(nameOf(f)) || !!starchKind(f);
      return !light && !earlierNames[nameOf(f)];
    }, fixes, 'dinner_new_item', 'العشا تكرار أخف — مفيش عناصر جديدة');
  });

  return { plan: plan, fixes: fixes };
}

// يضبط الجرامات ويعيد حساب السعرات/الماكروز لو per100 متوفرة
function setGramsSafe(entry, grams) {
  entry.grams = grams;
  const per = entry.food && entry.food.per100;
  if (per) {
    const k = grams / 100;
    entry.cals = Math.round((per.cal || 0) * k);
    entry.pro = +( (per.pro || 0) * k ).toFixed(1);
    entry.carb = +( (per.carb || 0) * k ).toFixed(1);
    entry.fat = +( (per.fat || 0) * k ).toFixed(1);
  } else if (entry.food) {
    // شكل المحرك: cal/pro/carb/fat لكل 100جم على food مباشرة
    const k = grams / 100;
    if (typeof entry.food.cal === 'number') entry.cals = Math.round(entry.food.cal * k);
    if (typeof entry.food.pro === 'number') entry.pro = +(entry.food.pro * k).toFixed(1);
    if (typeof entry.food.carb === 'number') entry.carb = +(entry.food.carb * k).toFixed(1);
    if (typeof entry.food.fat === 'number') entry.fat = +(entry.food.fat * k).toFixed(1);
  }
}

function absorbCalories(keep, removed) {
  if (!keep || !removed.length) return;
  const extra = removed.reduce(function (s, f) { return s + calsOf(f); }, 0);
  const food = keep.food || keep;
  const per = food.per100 ? Number(food.per100.cal) : Number(food.cal);
  if (extra > 0 && per > 0) setGramsSafe(keep, gramsOf(keep) + extra / per * 100);
}

module.exports = {
  validate, enforce,
  // مصنّفات معروضة للاختبارات/إعادة الاستخدام
  _pred: { isRice, isBread, isMacarona, isTuna, isYogurt, isFish, isCookedVeg, isSoup, isPotato, isSweetPotato, isSaladVeg, isEgg, isCheese, isFoul, isComplement, isAllowedFruit, starchKind },
  _meal: { isBreakfast, isLunch, isDinner, isSnack, isPre, isMainMeal, mealCals, dayCals, breakfastProteinKinds },
  DB,
};
