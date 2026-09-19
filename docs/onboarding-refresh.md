# تحديث الإنترو والتعريف بالتطبيق

## التنفيذ

- الإنترو الأصلي مدته 5.5 ثانية كما هو. بعد انتهائه، لو بدء التطبيق لم يكتمل، يتحرك بريق هادئ على الخط الواصل بين الأيقونات السفلية فقط، دون عداد أو نص تحميل. يتوقف عند مغادرة الشاشة، ويحترم إعداد تقليل الحركة.
- أربع صور أصلية جديدة مستقلة للصحة، والرياضة، والتغذية، والعادات اليومية. لا تستخدم صور البوسترات القديمة. الأخضر الداكن والعاجي مستمران من هوية التطبيق.
- الرسائل قصيرة ومحددة: «خطة تبدأ منك»، «اعرف تتمرّن إزاي»، «أكل تحبّه ويناسبك»، «شوف تقدّمك خطوة بخطوة». النصوص عناصر Flutter مستقلة عن الصور، ولا تتضمن وعود نتائج أو ادعاء علاج طبي.
- عرض الصور بنسبة 4:5 وبـ `BoxFit.contain`؛ لا تمديد أو ضغط. مساحة الصورة تتكيف مع القياس الحقيقي للنص وحجم الخط، وأزرار التنقل ثابتة داخل SafeArea. المحتوى قابل للتمرير رأسيًا عند الخط الكبير جدًا أو الشاشة الأفقية.
- تمت مراجعة خلفيات تسجيل الدخول وإنشاء الحساب بصريًا مع اختبارات لوحة المفاتيح؛ لم يظهر عيب يستدعي تغيير تصميمهما.
- تحذير CI الخاص بـ `must_call_super` أُصلح باستدعاء `super.dispose()` داخل الكاميرا البديلة للاختبار، دون تجاهل التحذير.

## الأصول والملفات

الأصول النهائية في `mobile/assets/onboarding_v6/{health,sport,nutrition,habits}.webp`. الأربعة إجمالًا 538,504 بايت، بأبعاد 1122×1402 لكل صورة. تم استخدام أداة imagegen المدمجة، ثم تحويل صيغة الملفات إلى WebP؛ لم تُستخدم الصور القديمة كمرجع أو كجزء من الصور الجديدة.

التنفيذ في `mobile/lib/widgets/brand_onboarding_page.dart` و`brand_intro_scene.dart`، وربط الانتظار في `mobile/lib/screens/splash_screen.dart`، وإضافة مجلد الصور في `mobile/pubspec.yaml`. إصلاح CI في `mobile/test/form_coach_pipeline_test.dart`.

## التحقق الآلي والبصري

- `flutter test --no-pub`: 101 اختبار ناجح، واختبار تصدير الصور متجاوز افتراضيًا.
- `flutter analyze --no-fatal-infos --no-pub`: نجح دون أخطاء أو تحذيرات، مع 17 ملاحظة معلوماتية موجودة خارج التغيير.
- اختبار التصدير البصري شُغّل صراحة ونجح، وتمت معاينة صوره داخل `mobile/build/brand_review`.
- المقاسات المختبرة: 320×568، 360×640، 375×667، 360×800، 393×852، 412×915، 600×960، 800×1280. اختبارات إضافية بخط ×2 وشاشة أفقية 800×400، واستمرار حركة الانتظار وتوقفها واحترام تقليل الحركة.
- `node test/brand-experience-v5.test.js`: نجح بعد تحديث نصوص البوسترات المطلوبة مع الإبقاء على عقد توقيت الإنترو.

## Prompts used with built-in imagegen

Common prompt, prepended verbatim to each scene:

> Create one premium editorial 3D illustration for ElForma Arabic wellness mobile onboarding, portrait 4:5 composition. Palette warm ivory #F6F8ED, deep forest green #005438, sage green, restrained lime accents. Soft realistic matte materials, elegant studio daylight, tactile subtle shadows, clean sophisticated composition. Entire subject centered within middle 75 percent with generous margins on all sides, no cutoff objects. Warm ivory seamless background, no frame, no text, no letters, no logos, no watermark, no UI. Visually cohesive high-end wellness campaign, not a collage, not stock photo.

Health:

> A considered health-planning still life: a forest-green stethoscope curves around a small ivory health journal opened on a low rounded sage plinth, with a simple embossed heart relief on an upright translucent sage disc behind it, one delicate olive branch to the side. Calm, reassuring, a thoughtful personal starting point. No medicines, no pills, no needles. Realistic coherent scale, warm light from upper left.

Sport:

> A dynamic yet minimal exercise still life: a beautifully detailed pair of forest-green dumbbells, one leaning naturally against the other, a rolled sage training mat behind them and ivory athletic shoes beside the mat. Low architectural rounded plinths, one sweeping sage ribbon suggesting controlled motion, entirely different composition from generic gym photo. All objects fully visible, no people.

Nutrition:

> A beautiful Egyptian balanced meal on an ivory ceramic plate seen at an elevated three-quarter angle, delicious grilled chicken slices, small portion rice, cucumber tomato salad and herbs, a small olive-oil carafe next to the plate, folded forest-green linen napkin underneath. One sculptural pale-sage circular panel behind it, appetizing natural details, elegant food photography translated to premium realistic 3D. No broth, no floating food, whole plate visible.

Habits:

> Daily consistency represented by a forest-green reusable water bottle, a small ivory walking shoe pair, an analog desk clock with simple blank tick marks but no numerals, and a sage habit journal with a subtle embossed rising path on its cover, arranged thoughtfully on two low ivory curved platforms with a small living olive sprig. Gentle sunrise lighting, restful optimistic mood, no device screens, no charts or writing.
