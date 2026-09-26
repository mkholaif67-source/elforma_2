import 'dart:io';
import 'dart:ui' as ui;
import 'package:elforma/widgets/brand_intro_scene.dart';
import 'package:elforma/theme.dart';
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
      debugDisableShadows = false;
      final key = GlobalKey();
      final out = Directory('build/brand_review')..createSync(recursive: true);
      for (final family in ['Cairo', 'MaterialIcons']) {
        final loader = FontLoader(family);
        for (final file in family == 'MaterialIcons'
            ? ['fonts/MaterialIcons-Regular.otf']
            : ['assets/fonts/Cairo-Variable.ttf']) {
          loader.addFont(rootBundle.load(file));
        }
        await loader.load();
      }
      Future<void> mount(Widget widget, Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
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
            'assets/auth/reference_logo.png',
            splashLogoAsset,
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

      const stillsOnly = true;
      for (var i = 0; i <= 165; i++) {
        if (stillsOnly && ![0, 30, 60, 90, 120, 150, 165].contains(i)) continue;
        await mount(Scaffold(body: BrandIntroScene(progress: i / 165)),
            const Size(390, 844));
        await save('intro-${i.toString().padLeft(3, '0')}', 2);
      }
      await mount(
          const Scaffold(body: BrandIntroScene(progress: 1, waiting: true)),
          const Size(390, 844));
      await tester.pump(const Duration(milliseconds: 800));
      await save('intro-waiting', 1);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      await mount(const AuthScreen(loadGeo: false), const Size(390, 844));
      await tester.pumpAndSettle();
      await save('auth-login', 2);
      await tester.ensureVisible(find.text('إنشاء حساب'));
      await tester.tap(find.text('إنشاء حساب'));
      await tester.pumpAndSettle();
      await save('auth-signup', 2);
      await tester.binding.setSurfaceSize(null);
      debugDisableShadows = true;
    },
    skip: !const bool.fromEnvironment('EXPORT_BRAND_VISUALS'),
  );
}
