# Onboarding v7 — تسليم التصميم

## النطاق
الأساس: ElForma-Workout-History-Analytics.zip، آخر ملف رفعه المستخدم. التعديلات محصورة في الأونبوردينج واختباراته وأصوله. لم تُستبدل النسخة بملف Form Coach الأقدم، ولم يتغير سجل التمرين أو التحليلات أو قاعدة البيانات أو إعدادات البناء.

## التنفيذ
- أربع شاشات: جدول تمرين مصمم لهدفك؛ خطة تغذية تناسب هدفك؛ متابعة الأداء أثناء التمرين؛ المتابعة الذكية.
- أربعة PNG شفافة مستقلة، 1254×1254، في mobile/assets/onboarding_v7. كل صورة خالية من النصوص والأزرار.
- الخلفية والقاعدة ومسارات توضيح الحركة مرسومة في Flutter. مسارات الجسم توضيحية ثابتة في الأونبوردينج فقط؛ ليست بيانات Form Coach أو عدادًا حيًا.
- العناوين والأوصاف والشارات والأزرار Text widgets فعلية بخط ElFormaArabic الموجود في المشروع. العنوان 28/700 والوصف 17/400 والزر 19/700، مع دعم تكبير النص واتجاه RTL.
- الشارات خارج الصورة في Wrap لمنع تداخل النص المكبّر مع الرسم. الأزرار أسفل الصفحة، والمحتوى قابل للتمرير عند الحاجة على الشاشات الصغيرة أو الخط الكبير.
- تم حذف تكرار اسم التطبيق من رأس الأونبوردينج فقط. لم يتغير شعار الإنترو أو توقيته أو شاشات الحساب.
- حركة دخول خفيفة 700ms دون تكرار مستمر، وتخفيض الحركة حسب إعداد الجهاز.
- مفتاح brand_onboarding_seen_v1 ومسار إنهاء الأونبوردينج محفوظان؛ لن يُعاد عرضه للمستخدمين الذين أكملوه بالفعل.

## العلاقة بالمرجع
النتيجة إعادة تركيب مستوحاة من المرجع، وليست قصًا حرفيًا أو تطابقًا بكسليًا. أُعيد توليد الصور بلا كتابة، والشارات مجمّعة أسفل الرسم لحماية وضوح النص. لا توجد أرقام ماكروز أو عدات مختلقة في الصور.

## الملفات المعدلة
- mobile/lib/widgets/brand_onboarding_page.dart
- mobile/lib/screens/responsive_brand_onboarding_screen.dart
- mobile/pubspec.yaml
- mobile/test/brand_experience_responsive_test.dart
- test/brand-experience-v5.test.js

## التحقق المنفذ
- فحص PNG: الصور الأربع RGBA وبها قناة شفافية حقيقية (0–255).
- Dart formatter: الملفات المعدلة تُحلل نحويًا بنجاح. هذا ليس flutter analyze.
- node test/brand-experience-v5.test.js: نجح، بما يشمل النصوص والأصول الجديدة والحفاظ على عقد الإنترو.
- اختبارات Flutter القائمة تشمل أحجام هواتف/تابلت وخط ×2 والوضع الأفقي؛ تم تحديث توقعات العناوين والزر لتطابق التصميم الجديد، لكنها لم تُنفذ في هذه البيئة.
- لم يُبنَ APK ولم تُنفذ تجربة على Android هنا. نجاح فحص المصدر لا يثبت غياب overflow على الجهاز.

ملف onboarding-preview.html معاينة تصميم في المتصفح تستخدم نفس الصور والخطوط، وليس لقطة من تطبيق Flutter. تعذر التقاطها آليًا لأن متصفح Playwright غير مثبت. مرجع الحكم النهائي هو واجهة التطبيق بعد بناء GitHub.

## إنشاء الأصول
استخدمت أداة imagegen المدمجة. PNGs الأصلية محفوظة في المشروع دون تحويل أو قص. Canva استُخدم لفحص فصل المرجع، لكن الصور النهائية مولدة بصورة مستقلة.

Prompts (built-in imagegen):
1. Isolated premium photorealistic forest-green textured hex dumbbell with curved forest-green satin ribbon and lime segment; transparent alpha, no text/labels/UI/podium/plants, soft upper-left studio lighting, entire object with margins.
2. Isolated ivory ceramic bowl with grilled chicken slices, rice, fresh tomato/broccoli/avocado salad; oblique food photography, transparent alpha, no labels/UI/background/pedestal, soft warm studio light.
3. Isolated adult Egyptian athlete in side-profile lowered bodyweight squat facing right, green shirt, charcoal joggers, white trainers; whole body, transparent alpha; no text, skeleton or ground. Tracking guide added separately in Flutter.
4. Three ascending ivory travertine cylindrical steps, forest-green weight plate, emerald bars and lime rising arrow; premium 3D, transparent alpha, no text/numbers/UI/background.
