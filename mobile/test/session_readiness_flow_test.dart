import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elforma/api.dart';
import 'package:elforma/screens/training_session_screen.dart';
import 'package:elforma/widgets/session_readiness_checkin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (_) async => null);
  });
  for (final skip in [false, true]) {
    for (final zone in ['ready', 'caution', 'low']) {
      testWidgets(
          '${skip ? 'skip' : 'complete'} warmup -> checkin -> $zone; resume and new session',
          (tester) async {
        final saved = <int, Map<String, dynamic>>{};
        var id = 1, posts = 0;
        final api = Api.forTesting(MockClient((request) async {
          Map<String, dynamic> result = {};
          if (request.url.path.endsWith('/session/start')) {
            result = {
              'session': {'id': id, 'status': 'active', 'sets': []}
            };
          } else if (request.url.path.endsWith('/session/readiness')) {
            if (request.method == 'POST') {
              posts++;
              final body = jsonDecode(request.body) as Map;
              expect(body['checkIn'].keys.toSet(),
                  {'sleepHours', 'fatigue', 'pain', 'readiness'});
              saved[id] = {
                'sessionId': id,
                'source': {'checkIn': body['checkIn']},
                'decision': {
                  'zone': zone,
                  'loadMultiplier': zone == 'ready' ? 1 : .7,
                  'setMultiplier': zone == 'ready'
                      ? 1
                      : zone == 'caution'
                          ? .75
                          : .5
                },
                'explanation': {
                  'titleAr': 'جاهزية اليوم',
                  'reasonAr': 'الجلسة دي فقط'
                }
              };
            }
            result = {
              'readiness': saved[id],
              'status': saved.containsKey(id) ? 'ready' : 'needs_checkin'
            };
          } else {
            result = {
              'sets': [],
              'coach': {'hasBase': false}
            };
          }
          return http.Response(jsonEncode(result), 200,
              headers: {'content-type': 'application/json'});
        }));
        final day = <String, dynamic>{
          'key': 'upper',
          'name': 'Upper',
          'exercises': [
            {'name': 'Test exercise', 'sets': 4, 'reps': '8-10'},
          ]
        };
        Future<void> mount() async {
          await tester.pumpWidget(
              MaterialApp(home: TrainingSessionScreen(day: day, api: api)));
          await tester.pumpAndSettle();
        }

        await mount();
        expect(posts, 0);
        expect(find.byType(SessionReadinessCheckin), findsNothing);
        final button = find.text(skip ? 'تخطي الإحماء' : 'خلصت الإحماء');
        await tester.scrollUntilVisible(button, 250);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(SessionReadinessCheckin), findsOneWidget);
        for (final label in ['من 6 إلى 8 ساعات', 'مش تعبان', 'مفيش', 'جاهز']) {
          final choice = find.text(label);
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();
        }
        final submit = find.text('ابدأ الجلسة المناسبة لي');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(find.byType(SessionReadinessCheckin), findsNothing);
        expect(
            find.text(
                '${zone == 'ready' ? 4 : zone == 'caution' ? 3 : 2} مجموعات'),
            findsOneWidget);
        expect((day['exercises'] as List).first['sets'], 4,
            reason: 'Plan remains unchanged');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await mount();
        expect(find.byType(SessionReadinessCheckin), findsNothing);
        expect(find.text('خلصت الإحماء'), findsNothing);
        expect(posts, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        id = 2;
        await mount();
        final again = find.text('تخطي الإحماء');
        await tester.scrollUntilVisible(again, 250);
        await tester.tap(again);
        await tester.pumpAndSettle();
        expect(find.byType(SessionReadinessCheckin), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
  testWidgets(
      'small RTL screen with large text remains scrollable and retries failed submit',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var submits = 0;
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: SessionReadinessCheckin(onSubmit: (_) async {
              submits++;
              return false;
            }))));
    for (final label in [
      'أقل من 6 ساعات',
      'تعب شديد',
      'واضح أو مزعج',
      'جاهزيتي قليلة'
    ]) {
      final choice = find.text(label);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
    }
    final submit = find.text('ابدأ الجلسة المناسبة لي');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(submits, 1);
    expect(find.text('تعذر حفظ إجاباتك. جرب تاني قبل ما تبدأ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
