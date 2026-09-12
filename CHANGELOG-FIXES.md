# ElForma — إصلاحات الصيانة (سبتمبر 2026)

## إعادة بناء Intro وOnboarding بشكل Responsive

- أُعيد بناء الـIntro كخط زمني سينمائي مدته 10 ثوانٍ بعناصر منفصلة وحركة
  جري متعددة الإطارات وسقوط مستقل لمكونات التغذية وتكوين متدرج للشعار.
- أصبح الشعار والنص العربي عنصرين مستقلين داخل `SafeArea`.
- أُعيد بناء الـOnboarding باستخدام `LayoutBuilder` مع تخطيط منفصل للموبايل
  والتابلت، بدون قيم Scale أو Y-offset ثابتة لكل صورة.
- أُضيفت اختبارات تخطيط لثمانية مقاسات من 320×568 حتى 800×1280.
- ثُبّت اختبار المشاهد الأربعة في CI بحيث يفحص كل صفحة مباشرة بدل الاعتماد
  على ضغطة متزامنة مع حركة `PageView` المستمرة.
- حُذفت صور الـIntro والـOnboarding القديمة نهائيًا بعد ربط البدائل الجديدة
  الموجودة داخل `mobile/assets/cinematic_v3/`.
- اختُصرت شاشة فشل الاتصال إلى عنوان واضح ومحاولة جديدة فقط، مع تحويلها إلى
  نفس الهوية الداكنة بدل الشاشة البيضاء المنفصلة عن تصميم التطبيق.

هذا الملف يوثّق أربع إصلاحات تمت على تطبيق الفلاتر (`mobile/`) — السبب الجذري
لكل مشكلة، ومكان الإصلاح بالظبط. لم يتم تغيير أي Logic خارج نطاق المشاكل.

---

## 1) شات «تعارف مع مدربك» — الزرار الباهت في نهاية الشات

**السبب الجذري:** الـ Flow مصمَّم أصلًا للانتقال التلقائي: دالة `_commit()` في
`lib/screens/profile_setup_screen.dart` بتشغّل `_save()` تلقائيًا فور الإجابة
على آخر سؤال (عبر `addPostFrameCallback`)، وأثناء الحفظ كان `_reviewComposer()`
بيعرض زرارًا معطّلًا (`saving ? null : _save`) عليه مؤشر تحميل — شكل باهت يوحي
إن التطبيق معلّق، رغم إن الحفظ نفسه سريع (حفظ بروفايل فقط، وتوليد الخطط بيتم
في صفحة التحليل — انظر FIX-CHAT-EXIT).

**الإصلاح (نفس الملف):**
- أثناء الحفظ التلقائي تظهر لوحة تجهيز واضحة ومقصودة «تمام! بنجهز خطتك…»
  (`_autoSavingPanel()`) بدل الزرار الباهت.
- الانتقال لصفحة التحليل ما زال يتم من `_save()` **بعد اكتمال عملية الحفظ
  بنجاح** — لم يتغير أي منطق انتقال أو حفظ.
- لو الحفظ فشل (شبكة مثلًا)، `saving` ترجع `false` ويظهر الزرار فعّالًا
  وClickable لإعادة المحاولة كما كان مصممًا.
- وضع التعديل (`_editMode`) لم يتأثر إطلاقًا.

## 2) تسجيل الخروج لا يرجع لشاشة الدخول

**السبب الجذري (سببان متآزران):**
1. `Api.logout()` في `lib/api.dart` كان **ينتظر رد الشبكة** (`POST
   /api/auth/logout` بمهلة قد تصل 70 ثانية لو السيرفر نائم) قبل أي شيء.
2. بعد الرد، كان يطلق إشعار `accountChanges` **بشكل متزامن** → المستمع
   `_accountReset` في `lib/screens/shell_screen.dart` يعيد بناء التبويبات
   ويدمّر شاشة الحساب → عند عودة `_logout()` في `account_screen.dart` يجد
   `mounted == false` فيلغي `pushAndRemoveUntil` بهدوء → لا انتقال أبدًا،
   والشاشات تعيد التحميل بدون جلسة فتظهر رسالة «الجلسة انتهت». (ولذلك كان
   الحل الوحيد قفل التطبيق وفتحه: السبلاش لا يجد كوكي فيعرض شاشة الدخول.)

**الإصلاح:**
- `lib/api.dart` → `logout()`: أصبح الخروج **محليًا فوريًا أولًا**: إلغاء
  الجلسة على السيرفر يُرسل في الخلفية (fire-and-forget بمهلة 8 ثوانٍ) مع
  إرفاق الكوكي صراحةً بالطلب ليصل معرِّفًا بالجلسة حتى بعد المسح المحلي، ثم
  يُمسح كل أثر محلي للحساب فورًا (epoch/كوكي/كاشات/طابور الحساب) مع تحمّل
  أي فشل في أي خطوة.
- `lib/screens/account_screen.dart` → `_logout()`: يُمسك `Navigator.of(context)`
  **قبل** أي `await` (الـ Navigator الجذري يظل صالحًا حتى بعد تدمير الشاشة)،
  وأُزيل بوّابة `mounted` التي كانت تلغي الانتقال، وأصبح الانتقال لشاشة الدخول
  يتم **دائمًا** حتى لو فشل أي تنظيف محلي.

**النتيجة:** ضغطة «تسجيل الخروج» = مسح فوري للجلسة + انتقال فوري لشاشة
`AuthScreen`، من غير إعادة تشغيل التطبيق.

## 3) بيانات داخلية ظاهرة في صفحة التحليل

**المشكلة:** `_dashboardView()` في `lib/screens/analysis_screen.dart` كان يعرض
سطرًا نصيًا من `_targets['calculation']` («الحساب استخدم وزن X كجم…») تحت كارت
السعرات.

**الإصلاح:** حُذف بلوك العرض فقط. البيانات نفسها ما زالت محفوظة كاملة داخل
`_targets['calculation']` لأي استخدام نظامي — تم التأكد بالبحث أنها لا تُقرأ
في أي مكان عرض آخر. لا تأثير على أي حسابات أو منطق.

## 4) شاشة بدء التشغيل — نص «بنجهز الاتصال بالخادم»

**المشكلة:** النص كان يظهر بمؤقّت ثابت (بعد 6 ثوانٍ ثم رسالة ثانية بعد 14
ثانية) بصرف النظر عن حالة الاتصال الفعلية — فيوحي بالبطء أو بمشكلة.

**الإصلاح (`lib/screens/splash_screen.dart`):**
- مؤشر **نسبة مئوية متحرك** (رقم + شريط تقدم متدرج بألوان البراند) مربوط
  بمراحل الإقلاع الفعلية عبر `_markProgress()`:
  - 8% بداية قراءة الجلسة المحلية → 22% عند انتهائها.
  - قفزة لـ 62% **فقط عند وصول رد حقيقي من السيرفر** (نجاح أو 401) — فشل
    الشبكة لا يحرك القفزة، بل يستمر الزحف البطيء تحت سقف المرحلة.
  - 100% لحظة الانتقال للشاشة التالية فقط.
- بين المراحل يتحرك المؤشر ببطء نحو سقف المرحلة (`_startProgressCreep`) فلا
  يتجمد ولا يكذب: لا يسبق الاتصال الفعلي ولا يتأخر عنه.
- النعومة تأتي من `_chaseProgress()` المربوطة بتيكات أنيميشن السبلاش الموجود
  أصلًا — **صفر تكلفة أداء إضافية** (لا Timer جديد بمعدل الإطارات).
- الرسالة النصية الوحيدة المتبقية تظهر فقط إذا طال الإقلاع البارد فعلًا
  (بعد 20 ثانية) بصياغة هادئة: «لسه بنجهز التطبيق — أول فتحة ممكن تاخد لحد دقيقة».
- منطق إعادة المحاولة الصامت (BOOT-RETRY) وبوابة التحديث والصيانة لم تتغير.

---

## فحص الأداء العام (بدون تغيير أي Logic)

تمت مراجعة المسارات الحرجة، والبنية الحالية سليمة أصلًا:
- `main.dart`: أول frame يُرسم فورًا والخدمات غير الحرجة تُسخَّن بعد الرسم.
- `api.dart`: كاش bootstrap بمهلة 45 ثانية + دمج الطلبات المتزامنة
  (in-flight dedup) + نمط INSTANT-OPEN (عرض النسخة المحفوظة فورًا والتحديث
  صامتًا عبر `bootstrapRevision`) + كاش قراءة مربوط بالحساب + مهلة GET‏ 30ث.
- `shell_screen.dart`: تبويبات lazy داخل IndexedStack + استطلاع الطابور
  الأوفلاين بتباطؤ تكيفي (20ث → 120ث) لتوفير البطارية.
- `home_screen.dart`: عرض من الكاش أولًا وتحديث خلفي بدون spinner.
- الشات: `ListView.builder` + أنيميشن دخول بمفاتيح ثابتة (لا إعادة حركة).
- الأصول (assets) صغيرة (أكبر ملف 172KB).

**أكبر مكسبَي أداء فعليين جاءا من الإصلاحات نفسها:**
1. تسجيل الخروج لم يعد ينتظر الشبكة إطلاقًا (كان ممكن يعلّق حتى 70 ثانية).
2. شاشة البداية أصبحت صادقة وسلسة بصريًا (إحساس سرعة حقيقي بدل نص ثابت).

لم تُضَف أي «تحسينات» عشوائية غير قابلة للتحقق — أي تغيير كان سيُجرى بدون
بيئة فحص Flutter كاملة كان سيخالف قاعدة عدم كسر المنطق القائم.

---

## ملاحظة للتحقق عندك

بيئة الصيانة هنا بدون Flutter SDK، لذلك تم فحص سلامة البنية (توازن الأقواس
ومراجعة المواضع المعدّلة) آليًا. يُنصح قبل البناء بتشغيل:

```bash
cd mobile
flutter analyze
flutter test
```

## الملفات المعدّلة (5 ملفات فقط)
- `mobile/lib/screens/profile_setup_screen.dart`
- `mobile/lib/api.dart`
- `mobile/lib/screens/account_screen.dart`
- `mobile/lib/screens/analysis_screen.dart`
- `mobile/lib/screens/splash_screen.dart`
# Cinematic brand experience v3

- Rebuilt the Intro as a fixed ten-second cinematic timeline with a real
  six-frame run cycle, independently falling ingredients, energy convergence,
  and a fragmented logo assembly.
- Removed critical text and logo placement from raster scene geometry; Flutter
  now owns the final logo and Arabic tagline placement inside `SafeArea`.
- Rebuilt first-run onboarding around `LayoutBuilder`, bounded artwork, shared
  aspect-safe assets, and separate phone/tablet layouts.
- Removed per-card hard-coded scale and Y-offset patches.
- Added layout regression coverage for six common phone and tablet sizes.
- Deleted the retired v2 runtime/reference artwork after replacing every code
  and pubspec reference with the dedicated `cinematic_v3` asset set.

## CI compile hotfix

- Fixed the onboarding `SafeArea.minimum` type mismatch by using a concrete
  `EdgeInsets` value (the four physical margins are unchanged).
- Converted the new local imports to package imports so they follow the
  project's analyzer policy.
