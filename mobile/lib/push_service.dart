// Optional Firebase transport. Local rendering is shared with polling to avoid duplicates.
import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:elforma/api.dart';
import 'package:elforma/background_poll.dart';

@pragma('vm:entry-point')
Future<void> elformaPushBackground(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await Api.I.init();
    // Fetch the authenticated inbox instead of trusting potentially outdated
    // audience data in a message delivered after logout/account switching.
    await BackgroundPoll.runOnce();
  } catch (_) {}
}

class PushService {
  PushService._();
  static final I = PushService._();
  bool _ready = false;
  Future<void>? _starting;

  Future<void> start() {
    if (_ready) return refreshToken();
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(elformaPushBackground);
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((_) { unawaited(BackgroundPoll.runOnce()); });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        unawaited(Api.I.registerDevice(token, Platform.isIOS ? 'ios' : 'android', kAppBuild));
      });
      _ready = true;
      await refreshToken();
    } catch (_) {
      // Missing native Firebase configuration must not break login or plan loading.
      _ready = false;
    }
  }

  Future<void> refreshToken() async {
    if (!_ready) return;
    try {
      final permission = await FirebaseMessaging.instance.getNotificationSettings();
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await Api.I.registerDevice(token, Platform.isIOS ? 'ios' : 'android', kAppBuild);
    } catch (_) {}
  }
}
