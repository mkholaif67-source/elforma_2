// ── ElForma · main.dart ──
// App entry point: sets up providers (ProfileStore, Api), theme and root routing.
// نقطة بدء التطبيق وتهيئة المزودات والثيم والتوجيه.

import 'dart:async';
import 'package:elforma/community_links.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elforma/api.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/screens/splash_screen.dart';
import 'package:elforma/notification_service.dart';
import 'package:elforma/models/smart_coach_store.dart';
import 'package:elforma/models/exercise_video_catalog.dart';
import 'package:elforma/connectivity_service.dart';
import 'package:elforma/background_poll.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(_reportError('flutter', details.exceptionAsString(), details.stack?.toString() ?? ''));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(_reportError('platform', error.toString(), stack.toString()));
    return true;
  };

  // أول frame لازم يظهر فورا. الخدمات المحلية غير الحرجة تسخن بعد الرسم،
  // وكل خدمة تحمي فشلها منفردة فلا خدمة بطيئة تحجز فتح التطبيق.
  runApp(const ElFormaApp());
  unawaited(_warmStartupServices());
}

Future<void> _ignoreStartup(Future<void> Function() task) async {
  try { await task(); } catch (_) {}
}

Future<void> _warmStartupServices() async {
  await Future<void>.delayed(const Duration(milliseconds: 80));
  await Future.wait<void>([
    _ignoreStartup(ExerciseVideoCatalog.I.load),
    _ignoreStartup(SmartCoachStore.I.init),
    _ignoreStartup(ConnectivityService.I.init),
  ]);
  // طلب إذن الإشعارات وإعداد background poll لا يمنعان أول شاشة.
  unawaited(_ignoreStartup(NotificationService.I.requestPermission));
  unawaited(_ignoreStartup(BackgroundPoll.setup));
}

bool? _crashReportsEnabled;
final Map<String, DateTime> _reportedErrors = <String, DateTime>{};
final List<DateTime> _reportTimes = <DateTime>[];

Future<void> _reportError(String type, String message, String stack) async {
  try {
    _crashReportsEnabled ??= (await SharedPreferences.getInstance()).getBool('privacy_crash_reports') == true;
    if (_crashReportsEnabled != true) return;
    final now = DateTime.now();
    _reportTimes.removeWhere((time) => now.difference(time) > const Duration(minutes: 1));
    final fingerprint = '$type|$message|${stack.split('\n').take(2).join('|')}';
    final last = _reportedErrors[fingerprint];
    if (_reportTimes.length >= 5 || (last != null && now.difference(last) < const Duration(minutes: 1))) return;
    _reportedErrors[fingerprint] = now;
    _reportTimes.add(now);
    await Api.I.sendClientEvent(type, message, stack);
  } catch (_) {}
}

class ElFormaApp extends StatelessWidget {
  const ElFormaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الفورمة',
      navigatorKey: CommunityLinks.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          // Keep the user's system text size instead of silently capping it.
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
