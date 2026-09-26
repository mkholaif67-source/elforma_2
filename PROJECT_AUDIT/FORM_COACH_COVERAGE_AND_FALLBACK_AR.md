# تقرير Form Coach — التغطية والـFallback

## 1) المسار الأساسي الحالي

المسار الأساسي لم يتغير:

`Current Exercise -> FormProfileRegistry -> FormCoachEngine -> CameraPosePipeline`

الـFallback لا يسبق الـRegistry ولا يستبدل أي Profile موجود. إذا نجح الـRegistry، يتم استخدام الـProfile الموجود كما هو.

تمت مراجعة الـprofiles الحالية، وتشمل Profiles مخصصة لـ:

- Biceps Curl
- Bodyweight Squat من الجنب والأمام
- Lateral Raise
- Incline Barbell Press
- Machine Leg Extension
- Lat Pulldown

كما توجد طبقة catalog tracking-only مشتركة لعائلات الحركات الموجودة فعليًا. هذه الطبقة لا تعطي form correction عندما لا توجد Rules معايرة؛ تكتفي بالعدات والـmovement phase والـROM الظاهر.

## 2) Coverage التمارين الفعلية

مصدر البيانات الحالي يحتوي على **141 تمرينًا**.

- **126 تمرينًا** لها mapping داخل Form Coach.
- **15 تمرينًا** متعطلة عمدًا لأن الـpose الحالي لا يستطيع تقييمها بثقة بدون تخمين:
  - أنواع wrist curl
  - leg curl المحجوب أو غير المناسب للـpose
  - Cable Overhead Curl
  - Hammer Strength Incline Press
  - Farmer Walk
  - Dead Hangs
  - Plank / Plank on Cable
  - Mountain Climbers
  - Dead Bug

هذا ليس نقصًا مخفيًا: الاختبار `form-coach-catalog-coverage.test.js` يثبت العدد، ويثبت قائمة الاستثناءات المتعمدة.

## 3) الحركة المشتركة التي تم الحفاظ عليها

الملف `catalog_form_profiles.dart` يعيد استخدام نفس الـengine والـMetricEvaluator بدل Detection منفصل لكل اسم جهاز.

العائلات المستخدمة:

- **Press / Fly:** حركة الكتف والكوع، مع اختلاف الزاوية والمعدة ممثلًا في الـprofile أو الـcamera view، بدون ادعاء قياس مسار البار أو القبضة.
- **Pull / Row:** حركة الكتف والكوع؛ لا يوجد ادعاء بقياس scapular mechanics أو الحمل.
- **Curl:** elbow flexion/extension، مع tracking لموضع الكوع في الـProfiles التي تمت معايرتها.
- **Extension:** يتم التفريق بين triceps والـleg extension عندما توجد دلائل كافية.
- **Squat / Lunge:** hip/knee/ankle chain ومدى زاوية الركبة، مع اختلاف side/front views.
- **Hinge:** hip angle/trunk change كـROM proxy فقط.
- **Raise:** arm elevation/abduction، مع عدم الادعاء بقياس دوران الكتف أو scapular/trap takeover.

## 4) ما يمكن قياسه بأمان

عند وضوح الـpose والـcamera view:

- rep phase
- approximate repetitions
- visible ROM proxy
- partial repetitions
- tempo/processing state عند وجود profile مناسب
- readiness: joints، framing، visibility، view، lighting، FPS

وتظل حالات الـengine الحالية محفوظة:

- Valid / Correct
- Incorrect عند وجود Rule موثوق فقط
- Incomplete
- Cannot Assess

الـtracking-only والـfallback لا يصدران حكمًا فنيًا Incorrect لأن الكاميرا لا ترى كل ما يلزم لذلك.

## 5) الـFallback Engine

الملف الجديد:

`mobile/lib/features/form_coach/profiles/fallback_form_engine.dart`

ويعمل فقط إذا فشل الـRegistry في إيجاد mapping موثوق.

يستخرج من البيانات المحلية الموجودة بالفعل:

- body region
- movement family
- joint actions
- plane/direction
- body position
- equipment
- unilateral/bilateral
- camera view
- confidence

ولا يستخدم:

- Internet
- External AI/LLM
- API calls
- تعديل Workout/Session/Database/Backend
- الاسم وحده بدون دليل ثانوي

### سلوك Exercise جديد

1. يحاول `FormProfileRegistry.lookup` أولًا.
2. إذا وجد Profile، يستخدم المسار الأساسي ولا يدخل Fallback.
3. إذا لم يجد Profile، يحلل family + دليل ثانوي مثل muscle أو equipment أو position.
4. إذا كانت الثقة كافية، ينشئ Runtime Profile مؤقتًا من `trackingOnly`.
5. الـRuntime Profile يتابع reps/visible ROM فقط.
6. لا يضيف Form Rules عامة ولا يحول النتيجة إلى Verified Profile.
7. إذا لم توجد أدلة كافية، يعيد `Cannot Assess` عمليًا برفض إنشاء FormCoachRequest بدل إعطاء Coaching خاطئ.
8. واجهة fallback تعرض بوضوح: `متابعة احتياطية: عدات ومدى فقط`.

## 6) الأداء وعدم كسر الموجود

تم الحفاظ على تحسينات Form Coach السابقة:

- bounded latest-frame processing
- frame واحد in-flight
- pending frame واحد فقط
- no unbounded camera queue
- camera/detector/stream disposal
- audio/camera/UX الحالي
- no writes to session, progress, database, or backend

## 7) التحقق

نجح:

- `form-coach-fallback-contract.test.js`
- `form-coach-catalog-coverage.test.js`
- `form-coach-latency-contract.test.js`
- `npm run test:all` — 0 failures

Flutter/Dart غير متاحين في بيئة الفحص، لذلك يلزم تشغيل الآتي في CI أو على جهاز التطوير:

- `flutter analyze`
- `flutter test`
- `flutter build apk --release`
- اختبار camera/pose على أجهزة Android ضعيفة
- قياس FPS، latency، CPU، RAM، battery، والحرارة بجهاز فعلي

لم يتم ادعاء أن Fallback أو أي Rule جديد تمت معايرته على فيديوهات مستخدمين حقيقيين؛ لذلك بقي fallback tracking-only ومحافظًا.
