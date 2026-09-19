# تقرير Performance / Battery / Build Size النهائي

## 0) نطاق الفحص والـbaseline

تم العمل على آخر حزمة تم تسليمها قبل هذه المهمة:

- `elforma-formcoach-complete.zip`
- SHA-256 baseline: `1d22ff1ffaea4322cdbd89d762771a67a30477409b0f25ee17eb77bbed393ebf`

لم يتم عمل Rewrite أو Re-architecture، ولم يتم تغيير business logic أو UX أو Form Coach behavior.

## 1) مشكلة الـCI التي ظهرت في الصورة

تم إصلاحها قبل اعتماد أي تحسينات:

- `FormProfile?` كان يمرر إلى `FormCoachRequest.profile` المطلوب `FormProfile`؛ تم تثبيت non-null assertion بعد مسارات التحقق الموجودة.
- زر Retry في `workout_screen.dart` كان يشغّل Future داخل `VoidCallback` بدون `unawaited`؛ تم تحويله إلى fire-and-forget واضح.
- تم إصلاح أحرف UTF-8 replacement التالفة داخل `workout_screen.dart`.

الـsuite الكاملة بعد الإصلاحات:

`npm run test:all` → **0 failures**

## 2) Performance audit

### Startup

- `runApp` يحدث قبل تسخين الخدمات غير الحرجة.
- الخدمات المحلية (`ExerciseVideoCatalog`, `SmartCoachStore`, `ConnectivityService`) تبدأ بعد delay قصير وبشكل متوازٍ.
- صلاحيات الإشعارات وWorkManager لا تحجز أول شاشة.
- لم يتم إضافة startup work جديد.

**النتيجة:** التصميم الحالي مناسب لتقليل time-to-first-frame، لكن لا يوجد قياس startup فعلي لأن Flutter SDK غير متاح.

### Network / cache / account isolation

- bootstrap لديه in-flight dedupe وTTL قصير، مع revision للتحديث الفوري.
- persisted cache مفصول حسب account scope.
- login/logout/account change يمسح أو invalidates البيانات user-specific.
- background notification poll منفصل ومحدد، وForeground polling للحساب/الاشتراك guarded بالـforeground/account state.
- لم أغيّر polling أو TTL عشوائيًا حتى لا أسبب stale data أو أخفي تحديثًا مهمًا.

### Timers / listeners / lifecycle

تمت مراجعة timers وlisteners وsubscriptions في الشاشات الرئيسية. المسارات المهمة تلغي مواردها في `dispose` أو عند الخروج من foreground، ومنها Home وWorkout وMeal Plan وCommunity وShell وTraining Session وSteps وForm Coach.

لم يتم حذف timers التي لها وظيفة UI أو entitlement أو notification فعلية.

### Form Coach resources

المسار الحالي يحافظ على:

- camera `ResolutionPreset.medium`
- `enableAudio: false`
- ML Kit stream mode
- inference واحد in-flight
- latest pending frame واحد فقط
- لا يوجد frame queue غير محدود
- camera stream يتوقف عند pause
- detector/camera/stream/audio/recorder يتم التخلص منها عند dispose
- Wakelock يعمل فقط داخل Form Coach route ويعود لحالته عند الخروج

لا يوجد تعديل سلوكي جديد على Form Coach في هذه المهمة؛ فقط إصلاحات compile/encoding في المسار العام.

### الأداء العام

لم يظهر من الفحص النصي bottleneck مؤكد يستحق تغييرًا عالي المخاطر. لذلك لم يتم:

- تغيير polling policy
- حذف background WorkManager
- تغيير cache semantics
- رفع أو خفض Form Coach FPS
- تفعيل R8 بدون build validation
- إزالة dependency مستخدمة

## 3) Bundle / asset measurements الفعلية

هذه أرقام source/asset وليست APK/AAB:

- مجلد `mobile`: **15,487,796 bytes** تقريبًا.
- `mobile/assets`: نحو **13.6 MB**.
- الصور المقروءة: **108 صورة**، حجمها **11,939,322 bytes**.
- `brand_experience_v5`: **5,281,747 bytes** تقريبًا.
- `food_photos`: **5,367,944 bytes** تقريبًا.
- fonts الموجودة: **1,706,676 bytes** تقريبًا.
- Form Coach source: **218,025 bytes** تقريبًا.
- Form Coach لا يضيف assets أو audio/video files؛ الزيادة الأساسية المحتملة تأتي من native/plugin dependencies الخاصة بـCamera وML Kit وTTS.

### أكبر العناصر

- `brand_experience_v5/bowl.png`: 1.50 MB
- `brand_experience_v5/stones.png`: 1.09 MB
- `brand_experience_v5/athlete.png`: 0.68 MB
- `brand_experience_v5/dumbbell.png`: 0.60 MB
- عدة صور طعام WebP بحجم 640×640

وجدت نسخة مطابقة تمامًا:

- `oil.webp`: 91,374 bytes
- `olive_oil.webp`: 91,374 bytes

لم أحذف إحداهما لأنهما اسمان catalog مختلفان، وحذف أحدهما يحتاج تغيير mapping واختبار Flutter/واجهة الطعام؛ توفيرها في source حوالي 91 KB فقط ولا يثبت أنها ستقلل APK بدون تغيير references.

وجدت أيضًا 3 ملفات `NotoSansArabic` غير معلنة في `pubspec.yaml` وغير مستخدمة في source scan. لم أحذفها لأن حذفها يقلل repository footprint فقط، لا APK/AAB الحالي، ولا يستحق مخاطرة غير لازمة.

## 4) Build configuration والـAPK/AAB

الحالي:

- `release.isMinifyEnabled = false`
- `release.isShrinkResources = false`
- لا يوجد build output في البيئة الحالية.

يوجد `proguard-rules.pro` اختياري، لكنه متوقف عمدًا لأن المشروع يستخدم Camera وML Kit وFirebase وNotifications وWorkManager وGoogle Sign-In وTTS. تفعيل R8/resource shrinking قد يقلل الحجم، لكنه يحتاج build وruntime validation حقيقيين قبل اعتماده.

الـworkflow الحالي:

- `flutter build apk --release` بدون `--split-per-abi` ينتج APK universal/fat نسبيًا.
- release workflow يبني APK وAAB.
- AAB/Google Play يمكن أن يقلل download/install footprint عبر ABI/resource delivery مقارنةً بـuniversal APK، لكن لم يتم قياس الفرق فعليًا لعدم وجود Flutter/Gradle build في البيئة.

## 5) ما تم تغييره بأمان

تم تغيير الآتي فقط:

- إصلاح nullable compile blocker في Form Coach request.
- إصلاح `unawaited` warning في Retry callback.
- إصلاح UTF-8 corruption في Workout source.

لم يتم حذف Features أو dependencies أو assets، ولم يتم تفعيل build optimization غير قابل للتحقق.

## 6) Before / After ودرجة اليقين

### مقاس فعلي

- قبل/بعد APK: **غير مقاس**؛ لا يوجد Flutter SDK ولا build artifact.
- قبل/بعد AAB: **غير مقاس**.
- native library/ABI breakdown: **غير مقاس** بدون APK/AAB analyzer.
- Form Coach source footprint المقاس: **218 KB** تقريبًا، بدون assets خاصة به.

### أداء فعلي

- Node regression suite: **مقاس/منفذ ونجح، 0 failures**.
- Flutter analyze/test/build: **لم ينفذ** لعدم توفر Flutter/Dart.
- startup/FPS/jank/CPU/RAM/network/battery/heat: **ليست قياسات جهاز حقيقي**.

### Expected فقط

- latest-frame الموجود سابقًا يقلل stale-frame work وmemory backlog.
- startup ordering الحالي يقلل العمل قبل أول frame.
- cache/account guards تقلل requests وتحافظ على العزل.
- AAB delivery وR8 قد يقللان الحجم، لكن لا أضع نسبة متوقعة ولا أعتبرهما منفذين بدون build/QA.

## 7) Definition of Done المتبقي خارج البيئة

لتوقيع النتيجة نهائيًا على Android حقيقي:

1. `flutter pub get`
2. `flutter analyze --no-fatal-infos`
3. `flutter test`
4. `flutter build apk --release`
5. `flutter build appbundle --release`
6. `apkanalyzer` أو `bundletool` لتقسيم الحجم حسب dex/assets/native/ABI
7. Android Studio Profiler أو Perfetto لقياس CPU/RAM/jank/startup
8. Battery Historian أو Android Studio Energy Profiler للبطارية والـbackground
9. اختبار Form Coach بالكاميرا على جهاز منخفض الإمكانيات

لا توجد في هذا التقرير أي ادعاءات عن حرارة أو FPS أو Battery بدون القياس الفعلي المذكور أعلاه.
