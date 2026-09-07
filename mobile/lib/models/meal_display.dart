// ── ElForma · models/meal_display.dart ──
// Display-only helper that presents an engine meal the Egyptian way. When a
// meal contains two or more raw salad vegetables (خس/خيار/طماطم/جرجير…)
// they are merged into a single «سلطة» line — exactly how the website groups
// them — so the diet preview reads like a real plate instead of a repetitive
// pile of single vegetables. This changes nothing the engine computes: the
// merged row simply sums the grams and macros of its parts.
import 'engine_contracts.dart';

// Raw salad vegetables per the owner's canonical Egyptian list. Cooked
// vegetables (فاصوليا/بسلة/كوسة مطبوخة…) are intentionally NOT here — only
// raw items that belong on one «سلطة» plate the way the website groups
// cat=='veggie'.

// الزيت/الزبدة أصناف محسوبة على السيرفر. هذه الطبقة لا تنشئ أي كمية افتراضية.

/// يحول العناصر المركبة لأصناف حقيقية منفصلة: يدخل الزيت/الزبدة كصنف مستقل
/// بعد الصنف الأساسي مباشرة. Idempotent — مبيكررش لو العنصر المضاف موجود.
// السيرفر هو المصدر الوحيد لقرار إضافة الزيت/الزبدة وكميتهما. الموبايل لا
// يخلق إضافة اعتمادا على وزن الجبنة/الفول؛ فقط يحافظ على الإضافة المحسوبة.
List<NutritionFoodItem> expandCondiments(List<NutritionFoodItem> foods) =>
    List<NutritionFoodItem>.unmodifiable(foods);
const List<String> _saladKeywords = [
  'خس', 'طماطم', 'خيار', 'فلفل', 'جزر', 'بصل', 'كابوتشا', 'جرجير', 'فجل',
  'بقدونس', 'شبت', 'كزبرة', 'كرنب', 'خضار مشكل', 'سلطة',
];

/// The id carried by the merged «سلطة» display row.
const String saladGroupId = 'salad_group';

/// True when this row is a raw salad vegetable (or the merged salad plate).
/// المتدرب لازم يقدر يحذف طبق السلطة أو يعدل كميته، فالواجهة محتاجة
/// تعرف أي صفوف الوجبة اللي مكونة الطبق المدموج.
bool isSaladItem(NutritionFoodItem food) =>
    food.id == saladGroupId || _isSalad(food.name);

/// Positions of the real salad rows inside the meal's own food list.
List<int> saladIndexes(List<NutritionFoodItem> foods) {
  final out = <int>[];
  for (var i = 0; i < foods.length; i++) {
    if (_isSalad(foods[i].name)) out.add(i);
  }
  return out;
}

/// اسم المكون جوا القوسين. مفيش عندنا عنصر اسمه «سلطة خضراء بلدي»،
/// فلو داتا قديمة جاية بالوصف ده بننضفه قبل العرض.
String _saladPartName(String raw) {
  var s = raw.replaceAll(RegExp(r'سلطة|خضراء|خضرة|بلدي|مشكلة|مشكل'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

bool _isSalad(String name) {
  for (final k in _saladKeywords) {
    if (name.contains(k)) return true;
  }
  return false;
}

/// Returns the meal's foods with salad vegetables merged into one «سلطة»
/// row when two or more of them appear together. Meal order is preserved: the
/// merged row takes the position of the first salad item. When fewer than two
/// salad items exist the original list is returned untouched.
/// يشيل تكرار كلمة ملتصقة في الاسم زي «سمك بلطي مشوي مشوي» → «سمك بلطي مشوي».
String _dedupName(String name) {
  return name
      .replaceAllMapped(RegExp(r'(\S+)(\s+\1\b)+'), (m) => m[1]!)
      .trim();
}

/// نسخة من الصنف باسم منظف. الأنواع immutable فبنعيد البناء بنفس القيم.
NutritionFoodItem _withCleanName(NutritionFoodItem f) {
  final cleaned = _dedupName(f.name);
  if (cleaned == f.name) return f;
  return NutritionFoodItem(
    id: f.id,
    name: cleaned,
    grams: f.grams,
    calories: f.calories,
    protein: f.protein,
    carbs: f.carbs,
    fat: f.fat,
    hasCondiment: f.hasCondiment,
    condimentName: f.condimentName,
    condimentGrams: f.condimentGrams,
    isAddon: f.isAddon,
    pairGroup: f.pairGroup,
    addonMaxGrams: f.addonMaxGrams,
  );
}

/// ترتيب العناصر داخل الوجبة حسب طلب صاحب المشروع:
/// البروتين الأول، بعده الكارب، بعده السلطة/الخضار، بعده الزبادي، وأي حاجة تانية آخرا.
int _categoryRank(NutritionFoodItem f) {
  final t = '${f.name} ${f.id}';
  if (f.id == saladGroupId || _isSalad(f.name)) return 3; // سلطة / خضار
  if (RegExp('زبادي|لبن رايب|لبن رايب|zbady|laban').hasMatch(t)) return 4; // زبادي
  if (RegExp(
          'فراخ|فرخة|لحم|لحمة|كفتة|كبدة|سمك|تونة|تونه|بيض|رومي|بط|حمام|جمبري|سردين|سلمون|بروتين|بانيه|فول|جبن|قريش|frakh|lhm|smk|twna|byd|blty|kbda|kfta|slmwn|srdyn|jmbry|fwl|jbn|qrysh')
      .hasMatch(t)) {
    return 1; // بروتين
  }
  if (RegExp(
          'أرز|ارز|عيش|خبز|بطاطس|بطاطا|مكرون|شوفان|بليلة|فينو|توست|تورتيلا|كارب|arz|ays|khbz|btata|mkrwn|shwfan|tost|carb')
      .hasMatch(t)) {
    return 2; // كارب
  }
  return 5; // أي حاجة تانية
}

/// Returns the meal foods ordered by category. Linked oil/butter are rendered
/// as separate child rows immediately below their base food, never as standalone foods.
List<NutritionFoodItem> displayFoods(List<NutritionFoodItem> foods) {
  // 1) تنظيف الأسماء من التكرار.
  final cleaned = foods.map(_withCleanName).toList();

  // 2) دمج الخضار النيئة في طبق «سلطة» واحد.
  List<NutritionFoodItem> mergedList;
  final saladItems = cleaned.where((f) => _isSalad(f.name)).toList();
  // [OWNER-RULE نهائية] السيرفر يضمن 3 مكونات؛ العرض يجمعها دائمًا في طبق واحد.
  if (saladItems.isEmpty) {
    mergedList = cleaned;
  } else {
    num grams = 0, calories = 0, protein = 0, carbs = 0, fat = 0;
    final names = <String>[];
    for (final f in saladItems) {
      grams += f.grams;
      calories += f.calories;
      protein += f.protein;
      carbs += f.carbs;
      fat += f.fat;
      names.add(f.name);
    }
    // المكونات ديناميكية: الاسم بيتبني من المكونات الموجودة دلوقتي،
    // فأي إضافة أو حذف من مكونات الطبق بيتحدث في العرض أوتوماتيك.
    final parts = <String>[];
    for (final n in names) {
      final p = _saladPartName(n);
      if (p.isNotEmpty && !parts.contains(p)) parts.add(p);
    }
    final saladRow = NutritionFoodItem(
      id: 'salad_group',
      name: parts.isEmpty ? 'سلطة' : 'سلطة (${parts.join(' + ')})',
      grams: grams,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    final tmp = <NutritionFoodItem>[];
    var inserted = false;
    for (final f in cleaned) {
      if (_isSalad(f.name)) {
        if (!inserted) {
          tmp.add(saladRow);
          inserted = true;
        }
      } else {
        tmp.add(f);
      }
    }
    mergedList = tmp;
  }

  // 3) ترتيب الأصناف الأساسية: البروتينات معا، ثم الكارب، ثم الخضار.
  final bases = <NutritionFoodItem>[for (final f in mergedList) if (!f.isAddon) f];
  final indexed = <MapEntry<int, NutritionFoodItem>>[
    for (var i = 0; i < bases.length; i++) MapEntry(i, bases[i]),
  ]..sort((a, b) {
      final ra = _categoryRank(a.value), rb = _categoryRank(b.value);
      return ra != rb ? ra.compareTo(rb) : a.key.compareTo(b.key);
    });

  // 4) المكمل يظهر كسطر ابن مستقل تحت العنصر المرتبط مباشرة.
  final out = <NutritionFoodItem>[];
  for (final e in indexed) {
    final base = e.value;
    out.add(base);
    final pairIds = base.id == saladGroupId
        ? cleaned.where((f) => _isSalad(f.name)).map((f) => f.id).toSet()
        : <String>{base.id};
    out.addAll(mergedList.where((f) => f.isAddon && pairIds.contains(f.pairGroup)));
  }
  return out;
}
