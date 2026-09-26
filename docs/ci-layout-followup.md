# متابعة فشل اختبارات الواجهة — 20 سبتمبر 2026

الأساس: ElForma-Auth-Keyboard-Session-Fix.zip، دون الرجوع لنسخة أقدم.

الصورة الجديدة تعرض أربعة اختبارات فاشلة: الأونبوردينج 320×568، والكيبورد في إنشاء الحساب على ثلاثة مقاسات. تفاصيل assertion مطوية في الصورة؛ لذلك لا يمكن تأكيد أن كل فشل سببه الحصري ما يلي قبل تشغيل الاختبارات.

## الإصلاحات في الكود
1. auth_screen.dart / _revealFocusedField: كانت قراءة MediaQuery وموضع التمرير تتم داخل Timer مباشرة، ويمكن أن تسبق بناء الإطار الذي يحدّث مساحة الكيبورد. الآن يُنفذ العمل بعد layout باستخدام addPostFrameCallback مع ensureVisualUpdate؛ ويُتحقق مجددًا من mounted ووجود ScrollController. الحساب يتم باستخدام مساحة الشاشة الجديدة. هذا يعالج خصوصًا حالة إغلاق الكيبورد التي قد تُعامل سابقًا كأنه ما زال مفتوحًا.
2. brand_onboarding_page.dart / BrandOnboardingPage.build: استُبدل التقدير اليدوي لارتفاع Text/Wrap بقياس التخطيط الفعلي: ConstrainedBox + IntrinsicHeight + Column مع Expanded للرسم. النص الفعلي يرث إعدادات الثيم وتباعد الحروف، بينما TextPainter المنفصل السابق لم يضمن نفس القيم. لا يوجد حد أدنى مفروض للرسم يزاحم النص. في المساحة الضيقة جدًا يأخذ النص الأولوية؛ الرسم زخرفي ويقل حجمه حتى الصفر إن لزم. تبقى الصورة في شجرة الواجهات وتظل النصوص الكبيرة قابلة للتمرير.
3. _Artwork والرسامان: منع المقاسات السالبة وعدم الرسم عند مساحة صفرية. عزل LayoutBuilder داخل SizedBox ذي ارتفاع intrinsic معروف حتى لا يُطلب منه قياس intrinsic غير مدعوم.
4. flutter-apk.yml وmobile-release.yml: عرض نتائج flutter test بواسطة --reporter expanded لتوفير رسائل الفشل الفعلية. لا تعطيل اختبارات، ولا continue-on-error، ولا تجاوز شرط نجاحها.

نمط التخطيط مستخدم وفق توثيق Flutter لقسم Expanding content to fit the viewport:
https://api.flutter.dev/flutter/widgets/SingleChildScrollView-class.html

## ما تم التحقق منه فعليًا
- brand-experience-v5.test.js: ناجح.
- ui-accessibility-contract.test.js: ناجح.
- post-audit-hardening.test.js: 7 ناجحة.
- dart format --output=none --set-exit-if-changed: ناجح للملفين؛ فحص صياغة وليس type checking.
- مقارنة ZIP: تغير الملفان فقط في التطبيق، وملفا تقارير الاختبارات في GitHub. اختبارات Flutter ذاتها لم تُغير في هذه المتابعة. لا حذف ملفات أو أصول.

## ما لم يُتحقق منه
Flutter runtime غير متاح هنا، لذلك لم أشغّل الاختبارات الأربعة ولم أبن APK ولم أجرّب الكيبورد على جهاز Android. نجاح الفحوص السابقة لا يثبت نجاح GitHub. عند الرفع المعتاد سيظل GitHub يشغّل المجموعة كاملة، ويظهر تفاصيل أي فشل مباشرة. هذا التقرير يحل محل وصف الحساب اليدوي للرسم في تقرير التسليم السابق، ويُبقي حدوده التاريخية واضحة.
