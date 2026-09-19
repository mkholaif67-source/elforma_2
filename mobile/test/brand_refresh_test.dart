import 'package:elforma/widgets/brand_intro_scene.dart';
import 'package:elforma/widgets/brand_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'connection animates during startup wait, stops for reduced motion and on completion',
      (tester) async {
    Future<void> mount(bool waiting, {bool reduced = false}) async {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                  body: SizedBox(
                      width: 276,
                      height: 48,
                      child: BrandIntroConnection(
                          progress: 1, waiting: waiting))))));
    }

    CustomPainter painter() => tester
        .widget<CustomPaint>(find.byKey(const ValueKey('intro-connection')))
        .painter!;
    await mount(false);
    final still = painter();
    await tester.pump(const Duration(seconds: 3));
    expect(identical(still, painter()), true);
    await mount(true);
    final start = painter();
    await tester.pump(const Duration(milliseconds: 800));
    expect(painter().shouldRepaint(start), true);
    final next = painter();
    await tester.pump(const Duration(seconds: 4));
    expect(painter().shouldRepaint(next), true);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await mount(true, reduced: true);
    final reduced = painter();
    await tester.pump(const Duration(seconds: 3));
    expect(identical(reduced, painter()), true);
    await mount(false);
    final completed = painter();
    await tester.pump(const Duration(seconds: 3));
    expect(identical(completed, painter()), true);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(320, 568), const Size(800, 400)]) {
    testWidgets('all poster copy remains reachable with large text at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (var index = 0; index < 4; index++) {
        var taps = 0;
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: BrandOnboardingSurface(
                    key: ValueKey(index),
                    index: index,
                    onNext: () {
                      taps++;
                    },
                    pages: BrandOnboardingPage(index: index)))));
        await tester.pump();
        final subtitle = find.byKey(ValueKey('onboarding-subtitle-$index'));
        await Scrollable.ensureVisible(tester.element(subtitle), alignment: 1);
        await tester.pump();
        expect(tester.getRect(subtitle).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(FilledButton)).top));
        expect(
            tester
                .widget<Image>(find.byKey(ValueKey('onboarding-art-$index')))
                .fit,
            BoxFit.contain);
        await tester.tap(find.byType(FilledButton));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
