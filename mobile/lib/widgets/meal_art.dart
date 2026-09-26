import 'package:flutter/material.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/forma_design.dart';

// ── Food photo resolution ─────────────────────────────────────────────────────
// Match the food actually present; never borrow an unrelated dish's picture.
// Three reported defects are fixed here, each one reproduced against the real
// engine names before anything was changed:
//
//  1. `أرز أبيض مطبوخ` showed `eggs`. The old egg rule was the bare substring
//     `بيض`, which also lives inside `أبيض` / `بيضاء` / `جبنة بيضاء`, and it ran
//     before the rice rule. Egg matching is now word-anchored, so `أبيض` can
//     never trigger it and rice wins on its own name.
//  2. `فول مدمس` showed no photo at all. `app/diet/ui/food_index.js` stores that
//     name with a NO-BREAK SPACE (U+00A0) between the two words, so a pattern
//     written with a normal space could never match. Every input is now
//     normalised (whitespace, diacritics, hamza and ة/ه variants) first.
//  3. `سلطة (طماطم + خيار + فلفل أخضر)` showed `tomato`. Single-ingredient rules
//     ran before dish rules. Composite dishes are now matched first and bare
//     ingredients only afterwards.
//
// Perf: the rule table used to allocate and compile up to ~90 `RegExp` objects
// on *every* call, and `foodPhoto` runs several times per meal row per frame.
// Rules are compiled once now, and results are memoised.

final RegExp _diacritics = RegExp(
  '[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]',
);
final RegExp _nonWord = RegExp('[^0-9a-z\u0621-\u064A]+');

/// Collapses the many ways the same Egyptian food name reaches us: NBSP vs
/// space, `أ/إ/آ` vs `ا`, `ى` vs `ي`, `ة` vs `ه`, stray tashkeel, tatweel,
/// brackets and `+` separators. The result is padded with single spaces so
/// word-anchored patterns can rely on a separator existing on both sides.
String _normalize(String raw) {
  final stripped = raw.toLowerCase().replaceAll(_diacritics, '');
  final unified = stripped
      .replaceAll('\u0623', '\u0627') // أ → ا
      .replaceAll('\u0625', '\u0627') // إ → ا
      .replaceAll('\u0622', '\u0627') // آ → ا
      .replaceAll('\u0671', '\u0627') // ٱ → ا
      .replaceAll('\u0649', '\u064A') // ى → ي
      .replaceAll('\u0626', '\u064A') // ئ → ي
      .replaceAll('\u0624', '\u0648') // ؤ → و
      .replaceAll('\u0629', '\u0647'); // ة → ه
  return ' ${unified.replaceAll(_nonWord, ' ').trim()} ';
}

/// Builds a pattern that matches [stem] only as a standalone word, optionally
/// carrying an Arabic article/conjunction prefix or a plural/feminine suffix.
/// This is the guard that stops `بيض` from matching inside `أبيض`.
String _word(String stem) =>
    '(?:^| )(?:وال|بال|فال|ال|و|ب)?$stem(?:ه|ات|ين|ان)?(?= |\$)';

class _Rule {
  const _Rule(this.asset, this.patterns, {this.unless = const []});

  /// File name (without extension) under `assets/food_photos/`.
  final String asset;
  final List<String> patterns;

  /// Guards that veto the rule, e.g. `فول` must not match `فول سوداني`.
  final List<String> unless;
}

class _Compiled {
  _Compiled(this.asset, this.patterns, this.unless);
  final String asset;
  final List<RegExp> patterns;
  final List<RegExp> unless;

  bool matches(String text) {
    for (final guard in unless) {
      if (guard.hasMatch(text)) return false;
    }
    for (final pattern in patterns) {
      if (pattern.hasMatch(text)) return true;
    }
    return false;
  }
}

// Ordered most specific → most generic. Stage order matters: dishes before
// their own ingredients, cheeses before eggs, fats before nuts.
const List<_Rule> _rules = [
  // ── Composite dishes (must outrank their own ingredients) ──────────────────
  _Rule('lentil_soup', ['شوربه.*عدس', 'عدس.*شوربه', 'lentil soup']),
  _Rule('salad', [
    'سلطه',
    'سلاطه',
    'salad',
    'تبوله',
    'فتوش',
    'كول سلو',
    'coleslaw',
    'خيار.*طماطم',
    'طماطم.*خيار',
  ]),
  _Rule('molokhia', ['ملوخيه', 'molokhi']),
  _Rule('cooked_vegetables', [
    'خضار',
    'سبانخ',
    'spinach',
    'mixed veg',
    'cooked vegetable',
  ]),
  _Rule('soup', ['شوربه', 'مرق', 'soup', 'broth']),

  // ── Poultry ───────────────────────────────────────────────────────────────
  _Rule('liver', ['كبد.*فراخ', 'قوانص', 'chicken liver', 'gizzard']),
  _Rule('liver', ['كبده? ?اسكندراني', 'كبده', 'كبد', 'liver']),
  _Rule('kofta', ['كفت', 'kofta']),
  _Rule('turkey', [
    'ديك رومي',
    'صدر رومي',
    'ورك رومي',
    'رومي مشوي',
    'رومي مسلوق',
    'تركي مدخن',
    'turkey',
  ]),
  _Rule('chicken', ['فراخ', 'دجاج', 'chicken', 'تشيكن', 'شيش طاووق']),

  // ── Fish & seafood ────────────────────────────────────────────────────────
  _Rule('tuna', ['تونه', 'tuna']),
  _Rule('mackerel', ['ماكريل', 'mackerel']),
  _Rule('sardines', ['سردين', 'sardine']),
  _Rule('mullet', ['بوري', 'mullet']),
  _Rule('fish', [
    'بلطي',
    'tilapia',
    'سلمون',
    'salmon',
    'فيليه',
    'قاروص',
    'دنيس',
    'مرجان',
    'سنجاري',
    'بربوني',
    'بلاميطه',
    'قراميط',
    'شاخروه',
    'رنجه',
    'فسيخ',
    'انشوجه',
    'جمبري',
    'shrimp',
    'كابوريا',
    'crab',
    'سبيط',
    'كاليماري',
    'squid',
    'سمك',
    'fish',
  ]),

  // ── Red meat ──────────────────────────────────────────────────────────────
  _Rule('beef', [
    'لحمه',
    'لحم',
    'beef',
    'steak',
    'بسطرمه',
    'سجق',
    'حواوشي',
    'روست بيف',
    'roast beef',
    'ريش',
    'كرشه',
    'كوارع',
    'عكاوي',
  ]),

  // ── Cheese (before eggs: `جبنة بيضاء` is not an egg) ──────────────────────
  _Rule('cheese', ['قريش', 'cottage', 'ريكوتا', 'ricotta']),
  _Rule('roumy_cheese', [
    'جبنه? رومي',
    'roumy',
    'شيدر',
    'cheddar',
    'بارميزان',
    'parmesan',
    'جوده',
    'gouda',
    'ايدام',
    'فلامنك',
    'حلوم',
    'halloumi',
  ]),
  _Rule('white_cheese', [
    'جبنه بيضاء',
    'جبن ابيض',
    'فيتا',
    'feta',
    'white cheese',
    'رودس',
    'rods',
    'دمياطي',
    'اسطنبولي',
    'براميلي',
    'شلل',
    'لبنه',
    'مثلثات',
    'دوبل كريم',
    'كريمي',
    'موزاريلا',
    'موتزاريلا',
    'mozzarella',
    'ملح خفيف',
  ]),
  _Rule('cheese', ['جبنه', 'جبن', 'cheese']),

  // ── Eggs ──────────────────────────────────────────────────────────────────
  _Rule('omelette', ['اومليت', 'omelette', 'عجه']),
  _Rule('fried_eggs', ['بيض.*مقلي', 'مقلي.*بيض', 'fried egg']),
  _Rule('eggs', ['بياض بيض', 'بيض', '(?:^| )eggs?(?= |\$)']),

  // ── Yogurt & milk ─────────────────────────────────────────────────────────
  _Rule('yogurt', ['زبادي', 'yogurt', 'yoghurt', 'رايب']),
  _Rule('milk', ['لبن', 'حليب', 'milk']),

  // ── Legumes & pulses ──────────────────────────────────────────────────────
  // `فول مدمس` also arrives as `فول\u00A0مدمس`; normalisation handles it.
  _Rule(
    'beans',
    [
      'فول مدمس',
      'مدمس',
      'ful medames',
      'fool',
      'foul',
      'fava',
      'broad bean',
      'فول',
    ],
    unless: ['سوداني', 'صويا', 'peanut', 'soy'],
  ),
  _Rule('termis', ['ترمس', 'termis', 'lupin']),
  _Rule('loubia', ['لوبيا', 'black.?eyed', 'cowpea']),
  _Rule('green_beans', ['فاصوليا خضراء', 'فاصوليه خضراء', 'green bean']),
  _Rule('peas', ['بسله', 'بازلاء', 'peas']),
  _Rule('legumes', [
    'فول صويا',
    'حمص',
    'chickpea',
    'عدس',
    'lentil',
    'فاصوليا',
    'فاصوليه',
    'legume',
  ]),

  // ── Grains & starches ─────────────────────────────────────────────────────
  _Rule('rice_cake', ['رايس كيك', 'rice cake', 'rice cracker']),
  _Rule('rice', ['ارز', 'رز', 'بسمتي', 'basmati', 'كشري', 'koshary', 'rice']),
  _Rule('pasta', ['مكرونه', 'شعيريه', 'pasta', 'macaroni', 'spaghetti']),
  _Rule('sweet_potato', ['بطاطا', 'sweet potato']),
  _Rule('potato', ['بطاطس', 'potato', 'شيبسي', 'بيوريه']),
  _Rule('bread_brown', [
    'عيش اسمر',
    'خبز اسمر',
    'توست اسمر',
    'brown bread',
    'قمح كامل',
    'whole ?wheat',
    'عيش الشوفان',
    'عيش سن',
    'توست سن',
  ]),
  _Rule('bread_baladi', [
    'عيش بلدي',
    'خبز بلدي',
    'baladi',
    'عيش',
    'خبز',
    'توست',
    'toast',
    'bread',
    'رغيف',
    'تورتيلا',
    'tortilla',
  ]),

  // ── Vegetables (only after the salad/dish rules above) ────────────────────
  _Rule('tomato', ['طماطم', 'tomato']),
  _Rule('cucumber', ['خيار', 'cucumber']),
  _Rule('pepper', ['فلفل', 'pepper']),
  _Rule('carrot', ['جزر', 'carrot']),
  _Rule('lettuce', ['خس', 'lettuce', 'جرجير', 'rocket', 'arugula']),
  _Rule('okra', ['باميه', 'okra']),
  _Rule('zucchini', ['كوسه', 'زوكيني', 'zucchini', 'courgette']),

  // ── Fruit ─────────────────────────────────────────────────────────────────
  _Rule('apple', ['تفاح', 'apple']),
  _Rule('banana', ['موز', 'banana']),
  _Rule('dates', ['تمر', 'بلح', 'date']),
  _Rule('watermelon', ['بطيخ', 'watermelon']),
  _Rule('mango', ['مانجو', 'mango']),
  _Rule('grapes', ['عنب', 'grape']),
  _Rule('peach', ['خوخ', 'peach']),
  _Rule('apricot', ['مشمش', 'apricot']),
  _Rule('plum', ['برقوق', 'قراصيا', 'plum', 'prune']),
  _Rule('cactus_fig', ['تين شوكي', 'prickly pear', 'cactus fig']),
  _Rule('figs', ['تين', 'fig']),
  _Rule('melon', ['شمام', 'كانتالوب', 'melon', 'cantaloupe']),
  _Rule('guava', ['جوافه', 'guava']),
  _Rule('yousofi', ['يوسفي', 'يوسفندي', 'mandarin', 'tangerine']),
  _Rule('orange', ['برتقال', 'orange']),
  _Rule('strawberry', ['فراوله', 'strawberry']),
  _Rule('pomegranate', ['رمان', 'pomegranate']),
  _Rule('kaki', ['كاكا', 'كاكي', 'persimmon']),
  _Rule('kiwi', ['كيوي', 'kiwi']),

  // ── Fats & condiments (before nuts, so `زيت جوز الهند` is oil) ────────────
  _Rule('nuts', [
    'زبده فول سوداني',
    'زبده لوز',
    'زبده كاجو',
    'peanut butter',
    'almond butter',
  ]),
  _Rule('olive_oil', ['زيت زيتون', 'olive oil']),
  _Rule('olives', ['زيتون', 'olive']),
  _Rule('oil', ['زيت', 'oil', 'سمن', 'ghee']),
  _Rule('butter', ['زبده', 'زبد', 'butter']),
  _Rule('tahina', ['طحينه', 'طحين', 'tahini', 'tahina']),

  // ── Snacks ────────────────────────────────────────────────────────────────
  _Rule(
    'nuts',
    [
      'مكسرات',
      'سوداني',
      'peanut',
      'لوز',
      'almond',
      'كاجو',
      'cashew',
      'فستق',
      'pistachio',
      'بندق',
      'hazelnut',
      'عين جمل',
      'جوز',
      'walnut',
      'مكاديميا',
      'macadamia',
      'بيكان',
      'pecan',
      'nuts',
    ],
    unless: ['جوز الهند', 'جوز هند', 'coconut'],
  ),
  _Rule('seeds', [
    'سمسم',
    'sesame',
    'بذور',
    'sunflower seed',
    'pumpkin seed',
    'seeds',
    'لب',
  ]),
  _Rule('popcorn', ['فشار', 'popcorn']),
  _Rule('dark_chocolate', ['شوكولاته', 'شيكولاته', 'chocolate']),
  _Rule('coffee', ['قهوه', 'coffee']),

  // Real fruits with no dedicated photo still get the generic fruit plate,
  // which is truthful — unlike borrowing a different fruit's picture.
  _Rule('fruit', [
    'فاكهه',
    'fruit',
    'كرز',
    'cherry',
    'توت',
    'berry',
    'زبيب',
    'raisin',
    'اناناس',
    'pineapple',
    'جريب فروت',
    'grapefruit',
    'افوكادو',
    'avocado',
    'باشن فروت',
    'passion fruit',
    'سابوتا',
    'كمثري',
    'pear',
  ]),
];

/// Word-anchored stems. Anything listed here is wrapped in [_word] so it can
/// only match a whole word — this is the guard that keeps `أبيض` out of the egg
/// rule and `لب` out of every word that merely contains those two letters.
const Set<String> _anchored = {
  'سلطه',
  'سلاطه',
  'كبد',
  'كبده',
  'بيض',
  'جبن',
  'جبنه',
  'عجه',
  'لبن',
  'لبنه',
  'فول',
  'عدس',
  'حمص',
  'ارز',
  'رز',
  'عيش',
  'خبز',
  'خس',
  'لب',
  'زيت',
  'زبد',
  'زبده',
  'لوز',
  'تين',
  'سمك',
  'لحم',
  'لحمه',
  'ريش',
  'مرق',
  'جزر',
  'موز',
  'تمر',
  'بلح',
  'عنب',
  'خوخ',
  'كرز',
  'توت',
};

List<_Compiled>? _compiledRules;

List<_Compiled> _compile() {
  return _compiledRules ??= [
    for (final rule in _rules)
      _Compiled(
        rule.asset,
        [
          for (final pattern in rule.patterns)
            RegExp(
              _anchored.contains(pattern) ? _word(pattern) : pattern,
              caseSensitive: false,
            ),
        ],
        [for (final guard in rule.unless) RegExp(guard, caseSensitive: false)],
      ),
  ];
}

final Map<String, String?> _photoCache = {};

/// Resolves a food name to a photo asset key, or `null` when we genuinely have
/// no matching picture — the caller then shows a neutral placeholder instead of
/// an unrelated dish.
String? foodPhoto(String name) {
  if (name.isEmpty) return null;
  final cached = _photoCache[name];
  if (cached != null || _photoCache.containsKey(name)) return cached;

  final text = _normalize(name);
  String? asset;
  for (final rule in _compile()) {
    if (rule.matches(text)) {
      asset = rule.asset;
      break;
    }
  }

  // Distinct food names number in the low hundreds; the cap is a safety net.
  if (_photoCache.length > 512) _photoCache.clear();
  _photoCache[name] = asset;
  return asset;
}

/// Square food thumbnail. Decoding is capped to the drawn size so the large
/// source webp files are never decoded at full resolution into memory.
class FoodPhoto extends StatelessWidget {
  const FoodPhoto({super.key, required this.name, this.size = 58});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final key = foodPhoto(name);
    final extent = (size * MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0))
        .round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .27),
      child: SizedBox.square(
        dimension: size,
        child: key == null
            ? _placeholder()
            : Image.asset(
                'assets/food_photos/$key.webp',
                fit: BoxFit.cover,
                cacheWidth: extent,
                cacheHeight: extent,
                gaplessPlayback: true,
                // The food name is always rendered next to the photo, so the
                // image itself is decorative for screen readers.
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder() => ColoredBox(
    color: AppColors.bg2,
    child: Center(
      child: FormaIcon(
        Icons.restaurant_menu_rounded,
        size: size * .4,
        color: AppColors.nu,
      ),
    ),
  );
}

/// Meal thumbnail: the first food that has a photo, plus one contrasting
/// second food tucked into the corner.
class MealArt extends StatelessWidget {
  const MealArt({super.key, required this.names, this.size = 70});

  final List<String> names;
  final double size;

  @override
  Widget build(BuildContext context) {
    // One pass, one foodPhoto() call per name, stopping as soon as we have two.
    final byAsset = <String, String>{};
    for (final name in names) {
      final asset = foodPhoto(name);
      if (asset != null) byAsset.putIfAbsent(asset, () => name);
      if (byAsset.length == 2) break;
    }
    if (byAsset.isEmpty) {
      return FoodPhoto(name: names.join(' '), size: size);
    }
    final selected = byAsset.values.toList(growable: false);
    return SizedBox(
      width: size + (selected.length > 1 ? 22 : 0),
      height: size,
      child: Stack(
        children: [
          FoodPhoto(name: selected.first, size: size),
          if (selected.length > 1)
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                ),
                child: FoodPhoto(name: selected[1], size: size * .46),
              ),
            ),
        ],
      ),
    );
  }
}
