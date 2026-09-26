import 'package:elforma/screens/community_screen.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/meal_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'meal imagery never substitutes chicken for fish or an unknown food',
    () {
      expect(foodPhoto('صدر دجاج مشوي'), 'chicken');
      expect(foodPhoto('سمك بلطي مشوي'), 'fish');
      expect(foodPhoto('زبادي طبيعي'), 'yogurt');
      expect(foodPhoto('تفاحة'), 'apple');
      expect(foodPhoto('موز'), 'banana');
      expect(foodPhoto('أرز بسمتي'), 'rice');
      expect(foodPhoto('سمك ماكريل'), 'mackerel');
      expect(foodPhoto('تونة'), 'tuna');
      expect(foodPhoto('عيش بلدي'), 'bread_baladi');
      expect(foodPhoto('سلطة مشكلة'), 'salad');
      expect(foodPhoto('كبدة فراخ'), 'liver');
      expect(foodPhoto('صنف جديد غير معروف'), isNull);
    },
  );

  testWidgets(
    'recipe details remain reachable on a narrow phone with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.3)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: const RecipeScreen(
            item: {
              'title': 'طبق منزلي باسم طويل لاختبار وضوح عنوان الوجبة',
              'image': '',
              'servings': 2,
              'calories': 410,
              'cost': 100,
              'currency': 'EGP',
              'points': 5,
              'ingredients': ['المكون الرئيسي بالكمية الموضحة', 'مكون إضافي'],
              'preparation': ['الخطوة الأولى', 'الخطوة الأخيرة'],
              'highlights': ['ملاحظة من الفريق'],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final lastStep = find.text('2. الخطوة الأخيرة');
      await tester.dragUntilVisible(
        lastStep,
        find.byType(ListView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(lastStep.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
