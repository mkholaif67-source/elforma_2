// ── ElForma · background_poll.dart ──
// المسار الاحتياطي لإشعارات الأدمن: فحص دوري في الخلفية والتطبيق مقفول.
//
// ليه موجود: FCM لو التوكن مات أو المفتاح مش مضبوط، المتدرب ماكانش
// هيشوف الإشعار غير لما يفتح التطبيق بإيده. الفحص ده بيقفل الفجوة.
//
// ملاحزة مهمة: أندرويد مابيسمحش بفحص دوري أقل من 15 دقيقة، فأقل قيمة
// ممكنة هنا هي 15. الأدمن يقدر يزودها من إعدادات التطبيق في اللوحة.
//
// مفتاح 'seen_admin_notifs' متشارك مع shell_screen عمدا، عشان الإشعار اللي
// وصل في الخلفية مايتكررش كنافذة تاني لما يفتح التطبيق.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:elforma/api.dart';
import 'package:elforma/notification_service.dart';

/// اسم المهمة الدورية ومعرفها الفريد.
const String kPollTaskName = 'ef_admin_notif_poll';
const String kPollTaskId = 'ef_admin_notif_poll_unique';

/// نقطة دخول الـ isolate الخلفي. لازم تكون top-level ومعلمة بـ vm:entry-point
/// وإلا الـ tree shaking في وضع release بيشيلها والفحص مابيشتغلش خالص.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? inputData) async {
    try {
      await Api.I.init();
      await NotificationService.I.initialize();
      await BackgroundPoll.runOnce();
    } catch (_) {
      // فشل الفحص ماينفعش يتحول لإعادة محاولة لا نهائية.
    }
    return true;
  });
}

class BackgroundPoll {
  BackgroundPoll._();

  /// تشغيل الفحص الدوري. بيقرأ المدة من إعدادات التطبيق اللي الأدمن
  /// بيتحكم فيها، ولو الأدمن قافل الإشعارات بيلغي المهمة خلاص.
  static Future<void> setup() async {
    int minutes = 15;
    bool enabled = true;
    try {
      final res = await Api.I.getAppConfig();
      if (res.ok && res.data['appConfig'] is Map) {
        final cfg = Map<String, dynamic>.from(res.data['appConfig'] as Map);
        final raw = cfg['pollMinutes'];
        final parsed = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 15;
        minutes = parsed < 15 ? 15 : (parsed > 720 ? 720 : parsed);
        enabled = cfg['pushEnabled'] != false;
      }
    } catch (_) {}

    try {
      await Workmanager().initialize(backgroundDispatcher, isInDebugMode: false);
      // مهمة واحدة بمعرف ثابت، فإعادة التسجيل بتستبدل القديمة مابتكررهاش.
      await Workmanager().cancelByUniqueName(kPollTaskId);
      if (!enabled) return;
      await Workmanager().registerPeriodicTask(
        kPollTaskId,
        kPollTaskName,
        frequency: Duration(minutes: minutes),
        initialDelay: Duration(minutes: minutes),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {
      // منصة مابتدعمش المهام الخلفية → بنكمل عادي بالفحص عند الفتح.
    }
  }

  /// الفحص الفعلي: بيجيب إشعارات الأدمن ويعرض اللي المستخدم ماشافهوش.
  /// الفلترة بالجمهور والجدولة بتحصل على السيرفر مش هنا.
  static Future<void>? _inFlight;
  static Future<void> runOnce() => _inFlight ??= _run().whenComplete(() => _inFlight = null);

  static Future<void> _run() async {
    final revision=Api.I.sessionRevision,owner=Api.I.accountId;
    final seenKey='seen_admin_notifs:$owner';
    final res = await Api.I.getAdminNotifications();
    if (!res.ok || res.data['items'] is! List) return;
    final items = (res.data['items'] as List).whereType<Map>().toList().reversed;
    final dir = await getApplicationSupportDirectory();
    final lock = await File('${dir.path}/admin-notifications.lock').open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      final sp = await SharedPreferences.getInstance();
      await sp.reload();
      final seen = List<String>.from(sp.getStringList(seenKey) ?? const <String>[]);
      var shown = 0;
      for (final item in items) {
        if(revision!=Api.I.sessionRevision)return;
        final id = (item['id'] ?? '').toString();
        if (id.isEmpty || seen.contains(id)) continue;
        final expires = DateTime.tryParse((item['expires_at'] ?? '').toString());
        final scheduled = DateTime.tryParse((item['scheduled_at'] ?? '').toString());
        if (expires != null && expires.isBefore(DateTime.now())) continue;
        if (scheduled != null && scheduled.isAfter(DateTime.now())) continue;
        if (item['type'] == 'silent') { seen.add(id); continue; }
        if (shown > 0) await Future<void>.delayed(const Duration(seconds: 2));
        if(revision!=Api.I.sessionRevision)return;
        final phone = (item['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9+]'), '');
        final link = (item['link'] ?? '').toString();
        final delivered = await NotificationService.I.showAnnouncement(
          title: (item['title'] ?? 'إشعار من الفورمة').toString(),
          body: (item['body'] ?? '').toString(),
          id: notificationId(id),
          link: link.isNotEmpty ? link : (phone.isEmpty ? null : 'tel:$phone'),
          image: (item['image'] ?? '').toString(), phone: phone,
        );
        if (!delivered) continue;
        seen.add(id);
        // Persist each accepted notification, not only the end of the batch.
        await sp.setStringList(seenKey, seen.length > 1000 ? seen.sublist(seen.length - 1000) : seen);
        shown++;
        if (shown >= 5) break;
      }
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }

  static int notificationId(String id) {
    var hash = 2166136261;
    for (final c in id.codeUnits) { hash = ((hash ^ c) * 16777619) & 0x7fffffff; }
    return 10000 + hash % 2000000000;
  }
}
