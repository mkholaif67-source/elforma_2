import 'auth_field_finder.dart';
import 'reference_fonts.dart';
import 'auth_reveal_geometry.dart';
import 'package:elforma/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder field(String label) => authField(label);

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
  setUpAll(loadReferenceFonts);
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(393, 852),
  ]) {
    testWidgets('closed login keeps every action reachable at $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: AuthScreen(loadGeo: false)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(field('كلمة المرور')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.ensureVisible(find.text('المتابعة باستخدام Google'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('المتابعة باستخدام Google')).bottom,
        lessThanOrEqualTo(size.height),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  test(
    'minimal field reveal is stable across viewport boundaries',
    verifyAuthRevealGeometry,
  );
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

  testWidgets(
    'login fields keep their size and width through IME transitions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: AuthScreen(loadGeo: false)),
      );
      await tester.pumpAndSettle();
      final password = field('كلمة المرور');
      final before = tester.getRect(password);
      expect(before.height, greaterThanOrEqualTo(48));
      await tester.showKeyboard(password);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final during = tester.getRect(password);
      expect(during.width, closeTo(before.width, .5));
      expect(during.left, closeTo(before.left, .5));
      expect(during.height, closeTo(before.height, .5));
      expect(during.bottom, lessThanOrEqualTo(340));
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(tester.getRect(password).width, closeTo(before.width, .5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('registration editing reveals the field group and follows Next', (
    tester,
  ) async {
    await openSignup(tester, const Size(390, 844));
    final before = tester.getRect(field('الاسم الكامل'));
    await tester.showKeyboard(field('الاسم الكامل'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    for (final hint in [
      'الاسم الكامل',
      'البريد الإلكتروني',
      'رقم الهاتف',
      'كلمة المرور',
    ]) {
      final rect = tester.getRect(field(hint));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(544));
    }
    expect(
      tester.getRect(field('الاسم الكامل')).width,
      closeTo(before.width, .5),
    );
    final emailTop = tester.getRect(field('البريد الإلكتروني')).top;
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('البريد الإلكتروني')).focusNode!.hasFocus,
      isTrue,
    );
    expect(
      tester.getRect(field('البريد الإلكتروني')).top,
      closeTo(emailTop, .5),
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('رقم الهاتف')).focusNode!.hasFocus,
      isTrue,
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field('كلمة المرور')).focusNode!.hasFocus,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('login does not move a visible field when the full header fits', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen(loadGeo: false)),
    );
    await tester.pumpAndSettle();
    final input = field('البريد الإلكتروني أو رقم الهاتف');
    final before = tester.getRect(input);
    final headerBefore = tester.getSize(
      find.byKey(const ValueKey('auth-header')),
    );
    await tester.showKeyboard(input);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(tester.getRect(input), before);
    expect(
      tester.getSize(find.byKey(const ValueKey('auth-header'))),
      headerBefore,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'scrolling registration keeps typing active and preserves input',
    (tester) async {
      await openSignup(tester, const Size(360, 740));
      final name = field('الاسم الكامل');
      await tester.enterText(name, 'محمد');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final scroll = find.byType(SingleChildScrollView).first;
      await tester.drag(scroll, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(name).focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.widget<TextField>(name).controller!.text, 'محمد');
      await tester.ensureVisible(field('كلمة المرور'));
      await tester.tap(field('كلمة المرور'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(field('كلمة المرور')).bottom,
        lessThanOrEqualTo(440),
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
      final before = tester.getRect(field('كلمة المرور'));
      expect(before.height, greaterThanOrEqualTo(48));
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
      final during = tester.getRect(field('كلمة المرور'));
      expect(during.width, closeTo(before.width, .5));
      expect(during.height, closeTo(before.height, .5));
      expect(during.left, closeTo(before.left, .5));
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
      // Larger native fields may require scrolling on short displays.
      // The page must keep its geometry, not shrink to eliminate scrolling.
      expect(
        tester.getRect(field('كلمة المرور')).width,
        closeTo(before.width, .5),
      );
      await tester.ensureVisible(find.text('إنشاء حساب').last);
      expect(tester.takeException(), isNull);
    });
  }
}
