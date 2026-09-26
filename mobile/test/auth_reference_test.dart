import 'auth_field_finder.dart';
import 'reference_fonts.dart';
import 'package:elforma/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder input(String label) => authField(label);

Future<void> mount(WidgetTester tester,
    {Size size = const Size(390, 844), double scale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: const AuthScreen(loadGeo: false)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadReferenceFonts);
  testWidgets('supplied login and registration fit their 390 by 844 canvas',
      (tester) async {
    await mount(tester);
    expect(
        tester.getSize(find.byKey(const ValueKey('auth-header'))).height, 296);
    final email = tester.getRect(input('ادخل بريدك الإلكتروني أو رقم هاتفك'));
    expect(email.left, 24);
    expect(email.width, 342);
    expect(email.top, closeTo(355, 1));
    expect(
        tester.getRect(find.text('إنشاء حساب')).bottom, lessThanOrEqualTo(826));
    expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .maxScrollExtent,
        0);
    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();
    expect(
        tester.getSize(find.byKey(const ValueKey('auth-header'))).height, 176);
    final name = tester.getRect(input('اكتب اسمك بالكامل'));
    expect(name.left, 24);
    expect(name.top, closeTo(226, 1));
    expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .maxScrollExtent,
        0);
    final code = tester.getRect(find.text('+20'));
    expect(code.left, greaterThan(tester.getRect(input('رقم الهاتف')).right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('password visibility and remember-me remain interactive',
      (tester) async {
    await mount(tester);
    final pass = input('ادخل كلمة المرور');
    await tester.enterText(pass, 'Example123');
    expect(tester.widget<TextField>(pass).obscureText, true);
    await tester.tap(find.byTooltip('إظهار كلمة المرور'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(pass).obscureText, false);
    expect(tester.widget<TextField>(pass).controller!.text, 'Example123');
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
    await tester.tap(find.text('تذكرني'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
  });

  testWidgets('country change keeps phone input and registration validation',
      (tester) async {
    await mount(tester);
    await tester.tap(find.text('إنشاء حساب'));
    await tester.pumpAndSettle();
    await tester.enterText(input('رقم الهاتف'), '1012345678');
    await tester.tap(find.text('+20'));
    await tester.pumpAndSettle();
    await tester.enterText(input('ابحث عن الدولة أو الكود'), 'SA');
    await tester.pumpAndSettle();
    await tester.tap(find.text('+966'));
    await tester.pumpAndSettle();
    expect(find.text('+966'), findsOneWidget);
    expect(tester.widget<TextField>(input('رقم الهاتف')).controller!.text,
        '1012345678');
    await tester.ensureVisible(find.text('إنشاء حساب').last);
    await tester.tap(find.text('إنشاء حساب').last);
    await tester.pumpAndSettle();
    expect(find.text('الاسم مطلوب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('all auth actions remain reachable at $size with 2x text',
        (tester) async {
      await mount(tester, size: size, scale: 2);
      await tester.ensureVisible(find.text('إنشاء حساب'));
      await tester.tap(find.text('إنشاء حساب'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('المتابعة باستخدام Google'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('المتابعة باستخدام Google')).bottom,
          lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }
}
