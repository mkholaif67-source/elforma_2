import 'dart:io';
import 'dart:ui' as ui;
import 'package:elforma/widgets/brand_experience_visual.dart';
import 'package:elforma/widgets/brand_intro_scene.dart';
import 'package:elforma/widgets/brand_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/screens/auth_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'export production brand surfaces',
    (tester) async {
      final key = GlobalKey();
      final out = Directory('build/brand_review')..createSync(recursive: true);
      for (final family in ['ElFormaArabic', 'MaterialIcons']) {
        final loader = FontLoader(family);
        for (final file in family == 'MaterialIcons'
            ? ['fonts/MaterialIcons-Regular.otf']
            : [
                'assets/fonts/ElFormaArabic-Regular.ttf',
                'assets/fonts/ElFormaArabic-SemiBold.ttf',
                'assets/fonts/ElFormaArabic-Bold.ttf',
              ]) {
          loader.addFont(rootBundle.load(file));
        }
        await loader.load();
      }
      Future<void> mount(Widget widget, Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'ElFormaArabic'),
            home: RepaintBoundary(
              key: key,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: widget,
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (final asset in [
            ...BrandExperienceAssets.all,
            ...BrandOnboardingPage.assets,
            'assets/auth/hero_login.webp',
            'assets/auth/hero_signup.webp',
            'assets/auth/bottom_login.png',
            'assets/auth/bottom_signup.png',
            'assets/auth/brand_logo.png'
          ]) {
            await precacheImage(AssetImage(asset), key.currentContext!);
          }
        });
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
      }

      Future<void> save(String name, double ratio) async {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: ratio);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${out.path}/$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (var i = 0; i < 4; i++) {
        await mount(
          BrandOnboardingSurface(
            key: ValueKey(i),
            index: i,
            onNext: () {},
            pages: BrandOnboardingPage(index: i),
          ),
          const Size(432, 768),
        );
        await save('onboarding-${i + 1}', 2);
      }
      const stillsOnly = bool.fromEnvironment('BRAND_STILLS_ONLY');
      for (var i = 0; i <= 165; i++) {
        if (stillsOnly && ![0, 30, 60, 90, 120, 150, 165].contains(i)) continue;
        await mount(Scaffold(body: BrandIntroScene(progress: i / 165)),
            const Size(432, 900));
        await save('intro-${i.toString().padLeft(3, '0')}', 1.5);
      }
      await mount(
          const Scaffold(body: BrandIntroScene(progress: 1, waiting: true)),
          const Size(432, 900));
      await tester.pump(const Duration(milliseconds: 800));
      await save('intro-waiting', 1);
      for (final size in [
        const Size(320, 568),
        const Size(393, 852),
        const Size(800, 400)
      ]) {
        await mount(
            BrandOnboardingSurface(
                index: 0,
                onNext: () {},
                pages: const BrandOnboardingPage(index: 0)),
            size);
        await save('onboarding-health-${size.width.toInt()}', 1);
      }
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      await mount(const AuthScreen(loadGeo: false), const Size(390, 844));
      await tester.pumpAndSettle();
      await save('auth-login', 1.5);
      await tester.ensureVisible(find.text('إنشاء حساب'));
      await tester.tap(find.text('إنشاء حساب'));
      await tester.pumpAndSettle();
      await save('auth-signup', 1.5);
      await tester.binding.setSurfaceSize(null);
    },
    skip: !const bool.fromEnvironment('EXPORT_BRAND_VISUALS'),
  );
}
