import 'dart:io';
import 'dart:ui' as ui;
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/home_dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'reference_fonts.dart';

Future<void> loadHomeFonts() async {
  await loadReferenceFonts();
  for (final pair in {
    'Outfit': 'assets/fonts/Outfit-Variable.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf'
  }.entries) {
    await (FontLoader(pair.key)..addFont(rootBundle.load(pair.value))).load();
  }
}

Widget referenceSection(VoidCallback tap) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      IntrinsicHeight(
          child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Expanded(
                child: HomeMetricCard(
                    water: true,
                    value: '0.0',
                    subtitle: '0% من هدف 2.5 لتر',
                    onTap: tap)),
            const SizedBox(width: 12),
            Expanded(
                child: HomeMetricCard(
                    water: false,
                    value: 'ابدأ يومك',
                    subtitle: 'خطتك ووجباتك',
                    onTap: tap)),
          ])),
      const SizedBox(height: 14),
      const HomeWeeklyProgress(count: 1, target: 4),
      const SizedBox(height: 14),
      HomeWeightCard(current: 108, target: 100, onTap: tap),
      const SizedBox(height: 22),
      const Text('يومك أحسن بخطوة',
          style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w800,
              color: HomeDesign.forest)),
      const SizedBox(height: 12),
      HomeStepsCard(
          count: 20, goal: 6000, label: 'من هدفك اليومي 6000 خطوة', onTap: tap),
      const SizedBox(height: 12),
      HomeChallengeCard(
          title: 'تحدياتي', subtitle: 'ابدأ تحديا جديدا', onTap: tap),
      const SizedBox(height: 12),
      HomeKitchenCard(title: 'وصفات صحية بطعم تحبه', onTap: tap),
    ]);

void main() {
  setUpAll(loadHomeFonts);
  test('the shipped design fonts and first-name handling are consistent', () {
    expect(buildTheme().textTheme.bodyMedium!.fontFamily, 'Cairo');
    expect(buildTheme().textTheme.titleLarge!.fontFamily, 'Cairo');
    expect(HomeGreetingHeader.firstName('  mohamed  Ibrahim Ali '), 'Mohamed');
    expect(HomeGreetingHeader.firstName('أحمد\nمحمد علي'), 'أحمد');
    expect(HomeGreetingHeader.firstName('  '), '');
  });
  for (final width in [280.0, 320.0, 360.0, 390.0, 430.0, 600.0]) {
    for (final name in [
      'محمد عبدالرحمن علي',
      'Mohamed Ibrahim Ali',
      'عبدالرحمنعبدالرحيم محمد'
    ]) {
      testWidgets('single-line greeting at $width with $name', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 200);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            theme: buildTheme(),
            home: Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 200),
                        textScaler: TextScaler.linear(width == 280 ? 2 : 1)),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: HomeGreetingHeader(
                            name: name,
                            greeting: 'مساء الخير',
                            message: 'تمرينك ووجباتك جاهزين ليومك',
                            pro: true))))));
        await tester.pumpAndSettle();
        final label =
            tester.widget<Text>(find.byKey(const ValueKey('home-greeting')));
        expect(label.maxLines, 1);
        expect(label.softWrap, false);
        expect(label.textSpan!.toPlainText(),
            'مساء الخير يا ${HomeGreetingHeader.firstName(name)}');
        final rect =
            tester.getRect(find.byKey(const ValueKey('home-greeting')));
        expect(rect.left, greaterThanOrEqualTo(76));
        expect(rect.right, lessThanOrEqualTo(width - 16));
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'dashboard order, progress and actions survive text scale $scale',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: MediaQuery(
              data: MediaQueryData(
                  size: const Size(320, 900),
                  textScaler: TextScaler.linear(scale)),
              child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                      body: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: referenceSection(() => taps++)))))));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('المياه')).left,
          greaterThan(tester.getRect(find.text('التغذية')).left));
      final order = [
        find.byType(HomeMetricCard).first,
        find.byType(HomeWeeklyProgress),
        find.byType(HomeWeightCard),
        find.byType(HomeStepsCard),
        find.byType(HomeChallengeCard),
        find.byType(HomeKitchenCard)
      ];
      for (var i = 1; i < order.length; i++)
        expect(tester.getRect(order[i]).top,
            greaterThan(tester.getRect(order[i - 1]).top));
      for (var i = 0; i < 4; i++) {
        final segment =
            tester.widget<Container>(find.byKey(ValueKey('weekly-segment-$i')));
        expect((segment.decoration as BoxDecoration).color,
            i == 0 ? HomeDesign.emerald : HomeDesign.line);
      }
      for (final target in [
        find.text('المياه'),
        find.text('تسجيل الوجبة'),
        find.text('الوزن والمتابعة'),
        find.text('خطوات اليوم'),
        find.text('تحدياتي'),
        find.text('وصفات صحية بطعم تحبه')
      ]) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      expect(taps, 6);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('export supplied home section and production header',
      (tester) async {
    debugDisableShadows = false;
    final out = Directory('build/brand_review')..createSync(recursive: true);
    final key = GlobalKey();
    for (final entry in {
      'home-header': const Size(430, 100),
      'home-section': const Size(390, 710)
    }.entries) {
      await tester.binding.setSurfaceSize(entry.value);
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: RepaintBoundary(
              key: key,
              child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                      backgroundColor: HomeDesign.canvas,
                      body: Padding(
                          padding: const EdgeInsets.all(16),
                          child: entry.key == 'home-header'
                              ? const HomeGreetingHeader(
                                  name: 'Mohamed Ibrahim',
                                  greeting: 'صباح الإنجاز',
                                  message: 'تمرينك ووجباتك جاهزين ليومك',
                                  pro: true)
                              : referenceSection(() {})))))));
      await tester.runAsync(() async {
        for (final path in [
          'assets/logo_lockup.png',
          'assets/community/kitchen_hero.webp'
        ]) {
          await precacheImage(AssetImage(path), key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final bitmap = await (key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
        await File('${out.path}/${entry.key}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        bitmap.dispose();
      });
    }
    await tester.binding.setSurfaceSize(null);
    debugDisableShadows = true;
  }, skip: !const bool.fromEnvironment('EXPORT_BRAND_VISUALS'));
}
