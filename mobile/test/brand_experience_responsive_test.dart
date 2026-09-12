import 'package:elforma/screens/responsive_brand_onboarding_screen.dart';
import 'package:elforma/widgets/brand_experience_visual.dart';
import 'package:elforma/widgets/brand_intro_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _setSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  test('intro duration is fixed and independent from startup', () {
    expect(brandIntroDuration, const Duration(milliseconds: 5500));
  });

  const phoneAndTabletSizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(375, 667),
    Size(360, 800),
    Size(393, 852),
    Size(412, 915),
    Size(600, 960),
    Size(800, 1280),
  ];

  for (final size in phoneAndTabletSizes) {
    testWidgets('onboarding has no layout overflow at ${size.width}x${size.height}',
        (tester) async {
      await _setSurface(tester, size);
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ResponsiveBrandOnboardingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('أنت تستحق الأفضل دائمًا'), findsOneWidget);
    });
  }

  testWidgets('onboarding exposes the four approved storyboard pages',
      (tester) async {
    await _setSurface(tester, const Size(393, 852));
    const titles = <String>[
      'أنت تستحق الأفضل دائمًا',
      'جدول تمرين',
      'نظام غذائي',
      'عادات أفضل.. حياة أفضل',
    ];

    for (var index = 0; index < titles.length; index++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ResponsiveBrandOnboardingScreen(
              key: ValueKey('approved-onboarding-$index'),
              initialPage: index,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(titles[index]), findsOneWidget);
      expect(
        find.byIcon(
          index == titles.length - 1
              ? Icons.check_rounded
              : Icons.arrow_back_rounded,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  for (final kind in BrandVisualKind.values) {
    testWidgets('$kind preserves a bounded responsive composition',
        (tester) async {
      await _setSurface(tester, const Size(320, 420));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandExperienceVisual(kind: kind),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(BrandExperienceVisual), findsOneWidget);
    });
  }

  for (final size in phoneAndTabletSizes) {
    testWidgets('intro stays inside its safe composition at ${size.width}x${size.height}',
        (tester) async {
      await _setSurface(tester, size);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BrandIntroScene(progress: .72),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(BrandIntroScene), findsOneWidget);
    });
  }

  const cinematicCheckpoints = <double>[.10, .30, .50, .70, .90, 1];
  for (final checkpoint in cinematicCheckpoints) {
    testWidgets('intro scene at $checkpoint renders without runtime exceptions',
        (tester) async {
      await _setSurface(tester, const Size(393, 852));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrandIntroScene(progress: checkpoint),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
