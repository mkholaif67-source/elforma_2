import 'package:elforma/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

Future<void> openSignup(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(const MaterialApp(home: AuthScreen(loadGeo: false)));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('إنشاء حساب'));
  await tester.tap(find.text('إنشاء حساب'));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

void main() {
  testWidgets(
    'confirmation appears after a valid password without stealing focus',
    (tester) async {
      await openSignup(tester, const Size(390, 844));
      expect(field('تأكيد كلمة المرور'), findsNothing);
      await tester.enterText(field('كلمة المرور'), 'abc');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(field('تأكيد كلمة المرور'), findsNothing);
      await tester.enterText(field('كلمة المرور'), 'Example123');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(field('تأكيد كلمة المرور'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('كلمة المرور')).focusNode!.hasFocus,
        isTrue,
      );
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field('تأكيد كلمة المرور'))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(field('تأكيد كلمة المرور'), 'Example123');
      await tester.enterText(field('كلمة المرور'), 'Edit');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(field('تأكيد كلمة المرور'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('تأكيد كلمة المرور')).controller!.text,
        'Example123',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(360, 740),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    testWidgets('password and confirmation clear keyboard at $size', (
      tester,
    ) async {
      await openSignup(tester, size);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.showKeyboard(field('كلمة المرور'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(field('كلمة المرور')).bottom,
        lessThanOrEqualTo(size.height - 300),
      );
      await tester.enterText(field('كلمة المرور'), 'Example123');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(field('تأكيد كلمة المرور')).bottom,
        lessThanOrEqualTo(size.height - 300),
      );
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, closeTo(0, .5));
      expect(scrollable.position.maxScrollExtent, closeTo(0, .5));
      expect(tester.takeException(), isNull);
    });
  }
}
