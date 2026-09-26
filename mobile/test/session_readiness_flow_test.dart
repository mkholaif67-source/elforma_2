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
          (_) async => null,
        );
  });
  for (final skip in [false, true]) {
    for (final savedReadiness in [false, true]) {
      testWidgets(
        'warmup skip=$skip saved=$savedReadiness enters workout without questions',
        (tester) async {
          var posts = 0;
          var resumed = false;
          final api = Api.forTesting(
            MockClient((request) async {
              Map<String, dynamic> result;
              if (request.url.path.endsWith('/session/start')) {
                result = {
                  'session': {
                    'id': 1,
                    'status': 'active',
                    'sets': resumed
                        ? [
                            {
                              'exercise_key': 'test',
                              'set_number': 1,
                              'weight': 20,
                              'reps': 8,
                              'completed': true,
                            },
                          ]
                        : [],
                  },
                };
              } else if (request.url.path.endsWith('/session/readiness')) {
                if (request.method == 'POST') posts++;
                result = {
                  'readiness': savedReadiness
                      ? {
                          'source': {
                            'checkIn': {'sleepHours': 7},
                          },
                          'decision': {
                            'setMultiplier': .75,
                            'loadMultiplier': .7,
                          },
                          'explanation': {
                            'titleAr': 'جاهزية اليوم',
                            'reasonAr': 'جلسة محفوظة',
                          },
                        }
                      : null,
                };
              } else {
                result = {
                  'sets': [],
                  'coach': {'hasBase': false},
                };
              }
              return http.Response(
                jsonEncode(result),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          );
          final day = <String, dynamic>{
            'key': 'upper',
            'name': 'Upper',
            'exercises': [
              {
                'key': 'test',
                'name': 'Test exercise',
                'sets': 4,
                'reps': '8-10',
              },
            ],
          };
          Future<void> mount() async {
            await tester.pumpWidget(
              MaterialApp(
                home: TrainingSessionScreen(day: day, api: api),
              ),
            );
            await tester.pumpAndSettle();
          }

          await mount();
          if (!savedReadiness) {
            final button = find.text(skip ? 'تخطي الإحماء' : 'خلصت الإحماء');
            await tester.scrollUntilVisible(button, 250);
            await tester.tap(button);
            await tester.pumpAndSettle();
          }
          expect(find.byType(SessionReadinessCheckin), findsNothing);
          expect(
            find.text('${savedReadiness ? 3 : 4} مجموعات'),
            findsOneWidget,
          );
          expect(posts, 0, reason: 'Never invent answers');
          expect((day['exercises'] as List).first['sets'], 4);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          resumed = true;
          await mount();
          expect(find.byType(SessionReadinessCheckin), findsNothing);
          expect(find.text('خلصت الإحماء'), findsNothing);
          expect(posts, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
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
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: SessionReadinessCheckin(
              onSubmit: (_) async {
                submits++;
                return false;
              },
            ),
          ),
        ),
      );
      for (final label in [
        'أقل من 6 ساعات',
        'تعب شديد',
        'واضح أو مزعج',
        'جاهزيتي قليلة',
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
      expect(
        find.text('تعذر حفظ إجاباتك. جرب تاني قبل ما تبدأ'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
