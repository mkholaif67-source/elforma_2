// ── ElForma · main.dart ──
// App entry point: sets up providers (ProfileStore, Api), theme and root routing.
// نقطة بدء التطبيق وتهيئة المزودات والثيم والتوجيه.

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'notification_service.dart';
import 'models/smart_coach_store.dart';
import 'models/exercise_video_catalog.dart';
import 'connectivity_service.dart';
import 'background_poll.dart';

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
  unawaited(_ignoreStartup(NotificationService.I.initialize));
  unawaited(_ignoreStartup(BackgroundPoll.setup));
}

Future<void> _reportError(String type, String message, String stack) async {
  try {
    final sp = await SharedPreferences.getInstance();
    if (sp.getBool('privacy_crash_reports') != true) return;
    await Api.I.sendClientEvent(type, message, stack);
  } catch (_) {}
}

class ElFormaApp extends StatelessWidget {
  const ElFormaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'الفورمة',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}
