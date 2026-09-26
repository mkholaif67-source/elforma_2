import 'package:elforma/widgets/brand_intro_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _setSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  test('intro duration is fixed and independent from startup', () {
    expect(brandIntroDuration, const Duration(milliseconds: 3450));
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
    testWidgets(
      'intro stays inside its safe composition at ${size.width}x${size.height}',
      (tester) async {
        await _setSurface(tester, size);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: BrandIntroScene(progress: .72)),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(BrandIntroScene), findsOneWidget);
      },
    );
  }

  const cinematicCheckpoints = <double>[.10, .30, .50, .70, .90, 1];
  for (final checkpoint in cinematicCheckpoints) {
    testWidgets(
      'intro scene at $checkpoint renders without runtime exceptions',
      (tester) async {
        await _setSurface(tester, const Size(393, 852));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BrandIntroScene(progress: checkpoint)),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
