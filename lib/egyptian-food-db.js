'use strict';
// =============================================================================
// lib/egyptian-food-db.js
// المصدر الواحد الرسمي لعناصر الأكل المصري الشائعة — بالظبط زي ما حددها صاحب
// التطبيق، متقسّمة حسب الوجبة. العقل الغذائي بيبني النظام من القائمة دي لأنها
// أشهر أكل يومي للمصريين. المستخدم حر يضيف/يحذف عناصر من قاعدة ثانية، لكن دي
// قاعدة الحقيقة الافتراضية الوحيدة — مفيش قوائم أكل متكررة في أماكن تانية.
//
// الماكروز لكل 100 جم (بالشكل اللي بيتاكل بيه عادة) — قيَم قياسية معقولة.
// cat القيم: protein_chicken | protein_meat | fish | legume_cooked | cooked_veg
//            | soup | carb | dairy | egg | cheese | fruit | nut | fat | drink
//            | salad_veg | snackitem | other
// meals: أي وجبات ينفع العنصر يظهر فيها: breakfast | lunch | dinner | snack | pre
// =============================================================================

// ---- 1) الفطار ----
const BREAKFAST = [
  { id: 'foul',        nameAr: 'فول مدمس',   cat: 'legume_cooked', per100: { cal: 110, pro: 7.5, carb: 16, fat: 1.5 } },
  { id: 'gebna_2rish', nameAr: 'جبنة قريش',  cat: 'cheese',        per100: { cal: 98,  pro: 11,  carb: 3.4, fat: 4.3 } },
  { id: 'gebna_romy',  nameAr: 'جبنة رومي',  cat: 'cheese',        per100: { cal: 360, pro: 25,  carb: 2,   fat: 28 } },
  { id: 'gebna_rods',  nameAr: 'جبنة رودس',  cat: 'cheese',        per100: { cal: 280, pro: 18,  carb: 3,   fat: 22 } },
  { id: 'gebna_beda',  nameAr: 'جبنة بيضاء', cat: 'cheese',        per100: { cal: 260, pro: 14,  carb: 3,   fat: 21 } },
  { id: 'beid_me2ly',  nameAr: 'بيض مقلي',   cat: 'egg',           per100: { cal: 196, pro: 13,  carb: 1,   fat: 15 } },
  { id: 'beid_maslou2',nameAr: 'بيض مسلوق',  cat: 'egg',           per100: { cal: 155, pro: 13,  carb: 1.1, fat: 11 } },
  { id: 'batates_bf',  nameAr: 'بطاطس',      cat: 'carb',          per100: { cal: 87,  pro: 2,   carb: 20,  fat: 0.1 } },
  { id: 'eish_baladi', nameAr: 'عيش بلدي',   cat: 'carb',          per100: { cal: 250, pro: 9,   carb: 50,  fat: 1.5 } },
  { id: 'eish_asmar',  nameAr: 'عيش أسمر',   cat: 'carb',          per100: { cal: 247, pro: 9,   carb: 48,  fat: 2 } },
  { id: 'eish_abyad',  nameAr: 'عيش أبيض',   cat: 'carb',          per100: { cal: 265, pro: 9,   carb: 52,  fat: 2 } },
  { id: 'rice_cake',   nameAr: 'رايس كيك',   cat: 'carb',          per100: { cal: 387, pro: 8,   carb: 82,  fat: 3 } },
  { id: 'zabady_bf',   nameAr: 'زبادي',      cat: 'dairy',         per100: { cal: 61,  pro: 3.5, carb: 4.7, fat: 3.3 } },
];

// ---- 2) الغداء ----
const LUNCH_PROTEIN_CHICKEN = [
  { id: 'sadr_frakh',  nameAr: 'صدر فراخ',          cat: 'protein_chicken', per100: { cal: 165, pro: 31, carb: 0, fat: 3.6 } },
  { id: 'wrk_frakh',   nameAr: 'ورك فراخ',          cat: 'protein_chicken', per100: { cal: 209, pro: 26, carb: 0, fat: 11 } },
  { id: 'kwanes_kbda', nameAr: 'قوانص وكبدة فراخ',  cat: 'protein_chicken', per100: { cal: 143, pro: 22, carb: 1, fat: 5 } },
  { id: 'kofta_frakh', nameAr: 'كفتة فراخ',         cat: 'protein_chicken', per100: { cal: 190, pro: 20, carb: 2, fat: 11 } },
];
const LUNCH_PROTEIN_MEAT = [
  { id: 'lahma_maslou2', nameAr: 'لحم مسلوق', cat: 'protein_meat', per100: { cal: 250, pro: 26, carb: 0, fat: 15 } },
  { id: 'lahma_mashwy',  nameAr: 'لحم مشوي',  cat: 'protein_meat', per100: { cal: 271, pro: 27, carb: 0, fat: 18 } },
  { id: 'kofta_lahma',   nameAr: 'كفتة لحم',  cat: 'protein_meat', per100: { cal: 280, pro: 18, carb: 3, fat: 21 } },
  { id: 'kebda_lahma',   nameAr: 'كبدة لحم',  cat: 'protein_meat', per100: { cal: 175, pro: 27, carb: 4, fat: 5 } },
];
const LUNCH_FISH = [
  { id: 'blty_mashwy', nameAr: 'سمك بلطي مشوي', cat: 'fish', per100: { cal: 128, pro: 26, carb: 0, fat: 2.7 } },
  { id: 'makaryl',     nameAr: 'سمك ماكريل',    cat: 'fish', per100: { cal: 205, pro: 19, carb: 0, fat: 14 } },
  { id: 'bory',        nameAr: 'سمك بوري',      cat: 'fish', per100: { cal: 150, pro: 19, carb: 0, fat: 8 } },
  { id: 'sardin',      nameAr: 'سمك سردين',     cat: 'fish', per100: { cal: 208, pro: 25, carb: 0, fat: 11 } },
  { id: 'tuna',        nameAr: 'تونة',          cat: 'fish', per100: { cal: 116, pro: 26, carb: 0, fat: 1 }, maxGramsPerDay: 200 },
];
const LUNCH_COOKED_VEG_SOUP = [
  { id: 'lobya',       nameAr: 'لوبيا',           cat: 'legume_cooked', per100: { cal: 120, pro: 8,  carb: 20, fat: 1 } },
  { id: 'fasolya',     nameAr: 'فاصوليا',         cat: 'legume_cooked', per100: { cal: 127, pro: 9,  carb: 22, fat: 0.5 } },
  { id: 'fasolya_khadra', nameAr: 'فاصوليا خضراء',cat: 'cooked_veg',    per100: { cal: 35,  pro: 2,  carb: 7,  fat: 0.2 } },
  { id: 'besela_gazar', nameAr: 'بسلة بالجزر',    cat: 'cooked_veg',    per100: { cal: 70,  pro: 4,  carb: 12, fat: 0.5 } },
  { id: 'khodar_meshkl',nameAr: 'خضار مشكل',      cat: 'cooked_veg',    per100: { cal: 65,  pro: 3,  carb: 11, fat: 1 } },
  { id: 'molokhia',    nameAr: 'ملوخية',          cat: 'cooked_veg',    per100: { cal: 58,  pro: 4.6,carb: 5,  fat: 2 } },
  { id: 'batates_matbokha', nameAr: 'بطاطس مطبوخة',cat: 'cooked_veg',   per100: { cal: 90,  pro: 2,  carb: 20, fat: 0.5 } },
  { id: 'kosa_matbokha',nameAr: 'كوسة مطبوخة',    cat: 'cooked_veg',    per100: { cal: 40,  pro: 2,  carb: 6,  fat: 1 } },
  { id: 'shorbet_dagag',nameAr: 'شوربة مرقة دجاج', cat: 'soup',         per100: { cal: 38,  pro: 3,  carb: 3,  fat: 1.5 } },
  { id: 'shorbet_lahma',nameAr: 'شوربة مرقة لحمة', cat: 'soup',         per100: { cal: 44,  pro: 3,  carb: 3,  fat: 2 } },
  { id: 'shorbet_3ads', nameAr: 'شوربة عدس',      cat: 'soup',          per100: { cal: 116, pro: 9,  carb: 20, fat: 0.4 } },
];
const CARBS = [
  { id: 'rice_white',  nameAr: 'رز أبيض',   cat: 'carb', per100: { cal: 130, pro: 2.7, carb: 28, fat: 0.3 } },
  { id: 'rice_basmati',nameAr: 'رز بسمتي', cat: 'carb', per100: { cal: 130, pro: 2.7, carb: 28, fat: 0.3 } },
  { id: 'rice_brown',  nameAr: 'رز بني',    cat: 'carb', per100: { cal: 123, pro: 2.7, carb: 26, fat: 1 } },
  { id: 'eish_abyad_l',nameAr: 'عيش أبيض',  cat: 'carb', per100: { cal: 265, pro: 9,   carb: 52, fat: 2 } },
  { id: 'eish_baladi_l',nameAr: 'عيش بلدي', cat: 'carb', per100: { cal: 250, pro: 9,   carb: 50, fat: 1.5 } },
  { id: 'eish_asmar_l',nameAr: 'عيش أسمر',  cat: 'carb', per100: { cal: 247, pro: 9,   carb: 48, fat: 2 } },
  { id: 'macarona',    nameAr: 'مكرونة',    cat: 'carb', per100: { cal: 158, pro: 6,   carb: 31, fat: 1 } },
  // بطاطس كـكارب فقط لو مافيش خضار مطبوخ في نفس الوجبة (قاعدة في nutrition-rules).
  { id: 'batates_carb',nameAr: 'بطاطس',     cat: 'carb', per100: { cal: 87, pro: 2, carb: 20, fat: 0.1 }, onlyIfNoCookedVeg: true },
];

// ---- 3) طبق السلطة (عناصر يتحكم فيها المستخدم؛ مش خضار منفرد) ----
// أمثلة توليفات مسموحة: طماطم+خيار+فلفل أخضر، طماطم+خيار+جزر، طماطم+خيار+خس.
// ملاحظة: فلفل أخضر فقط — مش فلفل ملوّن.
const SALAD_ITEMS = [
  { id: 'tomato',      nameAr: 'طماطم',       cat: 'salad_veg', per100: { cal: 18, pro: 0.9, carb: 3.9, fat: 0.2 } },
  { id: 'cucumber',    nameAr: 'خيار',        cat: 'salad_veg', per100: { cal: 15, pro: 0.7, carb: 3.6, fat: 0.1 } },
  { id: 'green_pepper',nameAr: 'فلفل أخضر',   cat: 'salad_veg', per100: { cal: 20, pro: 0.9, carb: 4.6, fat: 0.2 } },
  { id: 'carrot',      nameAr: 'جزر',         cat: 'salad_veg', per100: { cal: 41, pro: 0.9, carb: 10,  fat: 0.2 } },
  { id: 'lettuce',     nameAr: 'خس',          cat: 'salad_veg', per100: { cal: 15, pro: 1.4, carb: 2.9, fat: 0.2 } },
];
const SALAD_PLATE_SIZE = 3; // طبق سلطة = 3 عناصر يتحكم فيها المستخدم

// ---- 4) المكمّلات (تكميلية، مش أساسية؛ تتحسب آخر حاجة) ----
const COMPLEMENTS = [
  // زيت: مرتبط بـ فول/جبنة (ماعدا الرومي)/سلطة. كمية متغيّرة 2..10 جم حسب الحاجة.
  { id: 'oil',    nameAr: 'زيت',   cat: 'fat', per100: { cal: 884, pro: 0, carb: 0, fat: 100 },
    complement: true, gramsMin: 2, gramsMax: 10, linkedTo: ['foul', 'gebna_2rish', 'gebna_rods', 'gebna_beda', 'salad'] },
  // زبدة: مرتبطة بـ بيض مقلي/فول. كمية متغيّرة 2..10 جم.
  { id: 'butter', nameAr: 'زبدة',  cat: 'fat', per100: { cal: 717, pro: 0.9, carb: 0.1, fat: 81 },
    complement: true, gramsMin: 2, gramsMax: 10, linkedTo: ['beid_me2ly', 'foul'] },
  // طحينة: مع السمك/الكفتة/الفراخ المشوية — حد أقصى 2..3 مرات/أسبوع (سقف مش أرضية).
  { id: 'tahina', nameAr: 'طحينة', cat: 'fat', per100: { cal: 595, pro: 17, carb: 21, fat: 54 },
    complement: true, gramsMin: 10, gramsMax: 25, maxPerWeek: 3,
    linkedTo: ['blty_mashwy', 'makaryl', 'bory', 'sardin', 'kofta_lahma', 'kofta_frakh', 'sadr_frakh'] },
  // زيتون مخلل: مقبلات أحياناً — حد أقصى 3 مرات/أسبوع، 40..50 جم لو ظهر.
  { id: 'olives', nameAr: 'زيتون مخلل', cat: 'other', per100: { cal: 115, pro: 0.8, carb: 6, fat: 11 },
    complement: true, appetizer: true, gramsMin: 40, gramsMax: 50, maxPerWeek: 3 },
];

// ---- 5) السناك (توليفات محددة — مش عناصر مبعثرة) ----
const SNACK_ITEMS = {
  fruit:      { id: 'fruit',      nameAr: 'فاكهة',          cat: 'fruit', per100: { cal: 60, pro: 1, carb: 15, fat: 0.2 } },
  nuts:       { id: 'nuts',       nameAr: 'مكسرات',         cat: 'nut',   per100: { cal: 607, pro: 20, carb: 21, fat: 54 } },
  termes:     { id: 'termes',     nameAr: 'ترمس',           cat: 'legume_cooked', per100: { cal: 120, pro: 16, carb: 10, fat: 3 } },
  popcorn:    { id: 'popcorn',    nameAr: 'فشار',           cat: 'carb',  per100: { cal: 387, pro: 13, carb: 78, fat: 4 } },
  dark_choco: { id: 'dark_choco', nameAr: 'شوكولاتة دارك',  cat: 'snackitem', per100: { cal: 546, pro: 5, carb: 61, fat: 31 } },
  zabady:     { id: 'zabady',     nameAr: 'زبادي',          cat: 'dairy', per100: { cal: 61, pro: 3.5, carb: 4.7, fat: 3.3 } },
};
// التوليفات المسموحة بالظبط (مصدر واحد):
const SNACK_COMBOS = [
  ['fruit', 'nuts'],
  ['termes'],
  ['popcorn'],
  ['termes', 'nuts'],
  ['popcorn', 'nuts'],
  ['dark_choco', 'fruit'],
  ['zabady', 'fruit'],
  ['zabady', 'nuts'],
];

// ---- 6) قبل التمرين ----
// القهوة السادة أساسية، ومعها عنصر واحد أو عنصرين من القائمة دي.
const PRE_WORKOUT_BASE = { id: 'black_coffee', nameAr: 'قهوة سادة', cat: 'drink', per100: { cal: 2, pro: 0.1, carb: 0, fat: 0 } };
const PRE_WORKOUT_ADDONS = [
  { id: 'banana',     nameAr: 'موز',           cat: 'fruit', per100: { cal: 89,  pro: 1.1, carb: 23, fat: 0.3 } },
  { id: 'apple',      nameAr: 'تفاح',          cat: 'fruit', per100: { cal: 52,  pro: 0.3, carb: 14, fat: 0.2 } },
  { id: 'dark_choco', nameAr: 'شوكولاتة دارك', cat: 'snackitem', per100: { cal: 546, pro: 5, carb: 61, fat: 31 } },
  { id: 'dates',      nameAr: 'تمر',           cat: 'fruit', per100: { cal: 282, pro: 2.5, carb: 75, fat: 0.4 } },
  { id: 'sweet_potato', nameAr: 'بطاطا', cat: 'carb', per100: { cal: 86, pro: 1.6, carb: 20, fat: 0.1 }, seasonal: true },
  { id: 'pomegranate',  nameAr: 'رمان', cat: 'fruit', per100: { cal: 83, pro: 1.7, carb: 19, fat: 1.2 }, seasonal: true },
];
const PRE_WORKOUT_MIN_ADDONS = 1;
const PRE_WORKOUT_MAX_ADDONS = 2;

// ---- التوليفات المصرية الصالحة للبروتين في الفطار (مصدر واحد) ----
// صالح: بيض+جبنة، جبنة+فول، فول+بيض، بيض مقلي+جبنة، جبنة+جبنة (لو نوعين مختلفين).
// غير صالح: جبنة+فول+بيض كلهم مع بعض.
const BREAKFAST_PROTEIN_MIXES = [
  ['egg', 'cheese'],
  ['cheese', 'legume_cooked'], // جبنة + فول
  ['legume_cooked', 'egg'],    // فول + بيض
  ['cheese', 'cheese'],        // نوعين جبنة مختلفين
];
const BREAKFAST_MIX_MAX_PROTEINS = 2; // ممنوع 3 بروتينات مع بعض في الفطار

// ---- سقوف يومية عامة (حدود قصوى مش أرضيات) ----
const DAILY_LIMITS = {
  tunaMaxGrams: 200,      // تونة ≤ 200 جم/يوم
  yogurtMaxGrams: 200,    // زبادي ≤ 200 جم/يوم، ومايتحطش كله في وجبة واحدة
  singleMealShareMax: 0.40, // وجبة واحدة ≤ 40% من اليوم لو فيه 3 وجبات أو أكثر
  singleMealShareMin: 0.35, // الهدف: توزيع 35–40%
};

function allItems() {
  const out = [];
  [BREAKFAST, LUNCH_PROTEIN_CHICKEN, LUNCH_PROTEIN_MEAT, LUNCH_FISH,
   LUNCH_COOKED_VEG_SOUP, CARBS, SALAD_ITEMS, COMPLEMENTS, PRE_WORKOUT_ADDONS]
    .forEach(function (arr) { arr.forEach(function (x) { out.push(x); }); });
  Object.keys(SNACK_ITEMS).forEach(function (k) { out.push(SNACK_ITEMS[k]); });
  out.push(PRE_WORKOUT_BASE);
  return out;
}
function byMeal(meal) {
  switch (meal) {
    case 'breakfast': return BREAKFAST.slice();
    case 'lunch':
    case 'dinner':
      return [].concat(LUNCH_PROTEIN_CHICKEN, LUNCH_PROTEIN_MEAT, LUNCH_FISH, LUNCH_COOKED_VEG_SOUP, CARBS);
    case 'snack': return Object.keys(SNACK_ITEMS).map(function (k) { return SNACK_ITEMS[k]; });
    case 'pre': return [PRE_WORKOUT_BASE].concat(PRE_WORKOUT_ADDONS);
    default: return [];
  }
}

module.exports = {
  BREAKFAST,
  LUNCH_PROTEIN_CHICKEN, LUNCH_PROTEIN_MEAT, LUNCH_FISH, LUNCH_COOKED_VEG_SOUP, CARBS,
  SALAD_ITEMS, SALAD_PLATE_SIZE,
  COMPLEMENTS,
  SNACK_ITEMS, SNACK_COMBOS,
  PRE_WORKOUT_BASE, PRE_WORKOUT_ADDONS, PRE_WORKOUT_MIN_ADDONS, PRE_WORKOUT_MAX_ADDONS,
  BREAKFAST_PROTEIN_MIXES, BREAKFAST_MIX_MAX_PROTEINS,
  DAILY_LIMITS,
  allItems, byMeal,
};
