# تسليم المهمة 1 — تكبير لوجو أيقونة Android

## النتيجة
تم تكبير **اللوجو فقط بنسبة 20% (Scale = 1.20x)** حول مركز Canvas، من دون تغيير الرسم أو ألوان البراند أو لون الخلفية `#F7F9F1`.

على Canvas الـ Adaptive Icon مقاس 108×108dp أصبحت حدود اللوجو الفعلية تقريبًا **68×47dp** بدلًا من **57×41dp**. العرض يتجاوز مرجع الـ Safe Zone (قطره نحو 66dp) بدرجة طفيفة مقصودة، مع بقاء مساحة أمان كبيرة حوله.

## سبب اختيار 20%
- الزيادة واضحة مقارنة بالحجم القديم، وليست تكبيرًا تجميليًا بسيطًا يصعب ملاحظته.
- لا يلامس اللوجو حواف Canvas.
- اختبار الأقنعة التمثيلية Circle وRounded Square وSquircle أعطى **0% بكسلات Alpha مقصوصة**.
- 20% حل وسط أفضل من زيادات أكبر قد تجعل الشعار مزدحمًا على Launchers ذات القص الأكثر شدة.

## الملفات المعدلة
### مصادر التوليد
- `mobile/assets/icon.png`
- `mobile/assets/icon_foreground.png`
- `mobile/pubspec.yaml` — إضافة مصدر Monochrome لإبقاء إعادة التوليد متوافقة.

### Android Manifest
- `mobile/android/app/src/main/AndroidManifest.xml` — إضافة `android:roundIcon="@mipmap/ic_launcher_round"`.

### Adaptive Foreground — كل الكثافات
- `mobile/android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png`
- `mobile/android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png`
- `mobile/android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png`
- `mobile/android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png`
- `mobile/android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png`

### Legacy `ic_launcher` — كل الكثافات
- `mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

## الملفات الجديدة
### Monochrome / Themed Icons (Android 13+)
- `mobile/assets/icon_foreground_monochrome.png`
- `mobile/android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_monochrome.png`
- `mobile/android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml`
- `mobile/android/app/src/main/res/mipmap-anydpi-v33/ic_launcher_round.xml`

### Round launcher
- `mobile/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`
- `mobile/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_round.png`

## التحقق
- أبعاد Foreground حسب الكثافة: 108، 162، 216، 324، 432 بكسل.
- أبعاد Legacy/round حسب الكثافة: 48، 72، 96، 144، 192 بكسل.
- حدود اللوجو في mdpi: `(18,32) → (86,79)`، أي 68×47 بكسل.
- Circle: لا قص.
- Rounded Square: لا قص.
- Squircle: لا قص.
- تم تشغيل اختبارات التحديات الحالية مستقلًا ونجحت؛ لم تُمس ميزة التحديات في هذه المهمة.

## ملاحظة بناء
تعذر إكمال Gradle resource task داخل بيئة التسليم لأن Gradle Wrapper احتاج تنزيل `gradle-8.14-bin.zip` ولم تكن البيئة قادرة على الوصول إلى `services.gradle.org`. تم بدلًا من ذلك التحقق محليًا من بنية ملفات PNG وXML والهندسة وعدم القص. يُنصح بتشغيل `./gradlew :app:processDebugResources` أو بناء APK في CI المتصل بالإنترنت قبل الإصدار.
