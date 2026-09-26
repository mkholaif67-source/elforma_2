# حالة تنفيذ برومبت Form Coach — تابع أداءك

## النطاق

تمت مراجعة وتنفيذ الجزء الخاص بميزة **Form Coach / تابع أداءك** فقط، بدون تعديل منطق Workout أو Session أو Progress أو قاعدة البيانات.

## البنود المنفذة في النسخة الحالية

- فتح Form Coach كمسار مستقل مع بقاء شاشة التمرين الأصلية كما هي.
- تحليل الحركة محلياً على الجهاز فقط.
- عدم إرسال الصور أو landmarks أو نتائج العد إلى السيرفر.
- `ResolutionPreset.medium` لتقليل استهلاك البطارية والحرارة.
- `enableAudio: false` في الكاميرا.
- إطار واحد فقط قيد التحليل في نفس الوقت، مع إسقاط الإطارات الزائدة.
- adaptive pacing عند بطء inference بدلاً من تراكم طابور التحليل.
- حالات تشغيل واضحة: بداية، فحص الجاهزية، countdown، تتبع حي، انتهاء.
- حالة `Cannot Assess` منفصلة عن الخطأ؛ لا يتم احتساب الوضع غير الواضح كعدة صحيحة.
- readiness checks للإضاءة، الرؤية، الإطار، الثبات، FPS، والـ landmarks المطلوبة.
- دورة عدة آمنة: top → excursion → bottom → return، مع منع false rep عند الانقطاع أو نصف الحركة.
- counters runtime-only: Attempts / Valid / Incorrect / Incomplete، ولا يتم حفظها في التقدم أو قاعدة البيانات.
- تبديل الكاميرا Front/Back مع إعادة تشغيل stream بنفس إعدادات الأداء.
- أوضاع الصوت: Coach / Tones / Mute. وضع Tones لا يشغل TTS.
- إيقاف stream وTTS والتحليل عند background أو interruption، وإعادة فحص الجاهزية عند العودة.
- wakelock أثناء الشاشة فقط، ثم إرجاع الحالة السابقة عند الخروج.
- إزالة support-level والتفاصيل الداخلية من النص الظاهر للمستخدم.
- التسجيل المحلي غير مفعل افتراضياً؛ لا يوجد upload أو حفظ صامت للملفات.

## قرار التسجيل المحلي

تم الإبقاء على `SetClipRecorder` كـ seam مع implementation معطّل. السبب أن تسجيل الفيديو بالتوازي مع pose inference قد يرفع الحرارة ويخفض FPS على الأجهزة الضعيفة. لن يتم تفعيله إلا مع:

1. ملف مؤقت محلي فقط.
2. مراجعة واضحة بعد المجموعة.
3. Save أو Delete صريح من المستخدم.
4. حذف تلقائي عند الخروج بدون قرار.
5. عدم وجود أي مسار رفع للسيرفر.

## قواعد الدعم

- `Tracking Only` يعرض التتبع والعداد فقط.
- لا يتم عرض تحذير Form غير موثوق.
- أي Form correction أقوى يحتاج dataset موسوم واختبار جهاز حقيقي قبل تفعيله.
- العناصر غير الآمنة أو غير القابلة للرؤية بوضوح تظل disabled أو tracking-only.

## الاختبارات المتاحة

- Form Coach Dart source contract: ناجح.
- Form Coach merged contract: ناجح.
- Form Coach behavioral audit contract: ناجح.
- فحص UTF-8 للمصادر: ناجح.

## غير قابل للإثبات داخل بيئة الفحص

لا يوجد Flutter/Dart SDK ولا جهاز Android حقيقي في البيئة الحالية، لذلك لا يمكن ادعاء نجاح:

- `flutter analyze`
- `flutter test`
- `flutter build apk --release`
- FPS والحرارة والبطارية على جهاز فعلي.

هذه البنود تحتاج CI أو جهاز Android حقيقي قبل اعتبار Form Coach production-ready بالكامل.
