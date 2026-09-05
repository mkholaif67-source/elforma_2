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
function isSaladVeg(f) { return catOf(f) === 'salad_veg'; }
function isEgg(f) { if (catOf(f) === 'egg') return true; const n = nameOf(f); return /بيض/.test(n) && !/بيضاء|جبن/.test(n); }
function isCheese(f) { return catOf(f) === 'cheese' || /جبن/.test(nameOf(f)); }
function isFoul(f) { return /فول/.test(nameOf(f)); }
function isComplement(f) {
  const food = (f && f.food) ? f.food : f;
  if (food && food.complement) return true;
  return /زيت|زبدة|طحينة|زيتون/.test(nameOf(f));
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
  const nonEmpty = meals.filter(function (m) { return mealCals(m) > 0; });
  const total = dayCals(plan);

  let tunaTotal = 0, yogurtTotal = 0;

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

    // 1) مفيش رز في الفطار أبدًا
    if (isBreakfast(meal) && hasRice) {
      v.push({ code: 'no_rice_breakfast', meal: label, msg: 'رز في الفطار — ممنوع' });
    }
    // 2) خضار مطبوخ XOR سلطة في نفس الوجبة
    if (hasCookedVeg && hasSalad) {
      v.push({ code: 'cookedveg_xor_salad', meal: label, msg: 'خضار مطبوخ + سلطة في نفس الوجبة' });
    }
    // 3) مفيش خضار مطبوخ/شوربة/بطاطس مع السمك/التونة
    if (hasFish && (hasCookedVeg || hasSoup || hasPotato)) {
      v.push({ code: 'no_cookedveg_soup_potato_with_fish', meal: label, msg: 'خضار مطبوخ/شوربة/بطاطس مع السمك' });
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
    // 8) وجبة واحدة ≤ 40% من اليوم (لو فيه 3 وجبات أو أكثر)
    if (nonEmpty.length >= 3 && total > 0) {
      const share = mealCals(meal) / total;
      if (share > L.singleMealShareMax + 0.02) {
        v.push({ code: 'meal_share_too_high', meal: label, msg: 'الوجبة بتاخد ' + Math.round(share * 100) + '% من اليوم (الحد 40%)' });
      }
    }

    foods.forEach(function (f) {
      if (isTuna(f)) tunaTotal += gramsOf(f);
      if (isYogurt(f)) yogurtTotal += gramsOf(f);
    });
  });

  // 5) تونة ≤ 200 جم/يوم
  if (tunaTotal > L.tunaMaxGrams) {
    v.push({ code: 'tuna_over_limit', meal: 'day', msg: 'إجمالي التونة ' + Math.round(tunaTotal) + 'جم > ' + L.tunaMaxGrams + 'جم' });
  }
  // 6) زبادي ≤ 200 جم/يوم
  if (yogurtTotal > L.yogurtMaxGrams) {
    v.push({ code: 'yogurt_over_limit', meal: 'day', msg: 'إجمالي الزبادي ' + Math.round(yogurtTotal) + 'جم > ' + L.yogurtMaxGrams + 'جم' });
  }

  // 9) العشا = تكرار أخف — مفيش عنصر جديد ماظهرش في الفطار/الغدا
  const earlierNames = {};
  meals.forEach(function (m) {
    if (isBreakfast(m) || isLunch(m)) foodsOf(m).forEach(function (f) { earlierNames[nameOf(f)] = true; });
  });
  meals.forEach(function (m) {
    if (!isDinner(m)) return;
    foodsOf(m).forEach(function (f) {
      const nm = nameOf(f);
      const light = isYogurt(f) || catOf(f) === 'fruit' || isComplement(f);
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
    const foods = foodsOf(meal);
    // 1) رز في الفطار → شيله
    if (isBreakfast(meal)) removeFrom(meal, isRice, fixes, 'no_rice_breakfast', 'مفيش رز في الفطار');

    // 4) رز مع تونة → شيل الرز (التونة ترتبط بالعيش لو محتاجة كارب)
    if (foods.some(isTuna)) removeFrom(meal, isRice, fixes, 'no_rice_with_tuna', 'مفيش رز مع التونة');

    // 3) سمك/تونة مع خضار مطبوخ/شوربة/بطاطس → شيل الخضار/الشوربة/البطاطس
    if (foods.some(isFish)) {
      removeFrom(meal, function (f) { return isCookedVeg(f) || isSoup(f) || isPotato(f); },
        fixes, 'no_cookedveg_soup_potato_with_fish', 'مفيش خضار مطبوخ/شوربة/بطاطس مع السمك');
    }

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
  capNutrient(isTuna, L.tunaMaxGrams, 'tuna_over_limit', 'تونة ≤ 200جم/يوم');
  capNutrient(isYogurt, L.yogurtMaxGrams, 'yogurt_over_limit', 'زبادي ≤ 200جم/يوم');

  // 9) العشا: شيل أي عنصر جديد (مش خفيف/ماظهرش قبل كده)
  const earlierNames = {};
  meals.forEach(function (m) {
    if (isBreakfast(m) || isLunch(m)) foodsOf(m).forEach(function (f) { earlierNames[nameOf(f)] = true; });
  });
  meals.forEach(function (m) {
    if (!isDinner(m)) return;
    removeFrom(m, function (f) {
      const light = isYogurt(f) || catOf(f) === 'fruit' || isComplement(f);
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

module.exports = {
  validate, enforce,
  // مصنّفات معروضة للاختبارات/إعادة الاستخدام
  _pred: { isRice, isBread, isMacarona, isTuna, isYogurt, isFish, isCookedVeg, isSoup, isPotato, isSaladVeg, isEgg, isCheese, isFoul, isComplement },
  _meal: { isBreakfast, isLunch, isDinner, isSnack, isPre, isMainMeal, mealCals, dayCals, breakfastProteinKinds },
  DB,
};
