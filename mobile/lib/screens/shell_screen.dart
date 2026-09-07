// ── ElForma · screens/shell_screen.dart ──
// Bottom-navigation shell that hosts the main tabs.
// الهيكل السفلي للتبويبات.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api.dart';
import '../theme.dart';
import '../notification_service.dart';
import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'workout_screen.dart';
import 'account_screen.dart';
import '../models/subscription_store.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.initialIndex = 0});

  /// Tab to open on first build: 0 home, 1 workout, 2 nutrition, 3 account.
  final int initialIndex;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> with WidgetsBindingObserver {
  late int _i = widget.initialIndex;

  // التبويبات محفوظة جوا IndexedStack، يعني الرئيسية بتتبني مرة واحدة ومابتعملش
  // initState تاني أبدا. عشان كده لما المستخدم كان بيعمل جدول في تبويب التمرين
  // ويرجع للرئيسية، كان بيلاقي «أنشئ جدولي» زي ما هي — البيانات القديمة.
  // العداد ده بيتزود كل ما نرجع للرئيسية فتعيد التحميل من السيرفر.
  int _homeRefresh = 0;
  late final List<Widget?> _pages = List<Widget?>.filled(4, null);

  Future<void> _openExternal(String raw) async {
    var value = raw.trim();
    if (value.isEmpty) return;
    if (!value.startsWith('http://') && !value.startsWith('https://')) value = 'https://$value';
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return HomeScreen(onGo: _go, refreshToken: _homeRefresh);
      case 1: return const WorkoutScreen();
      case 2: return const MealPlanScreen();
      default: return const AccountScreen();
    }
  }

  void _refreshHomePage() {
    if (_pages[0] != null) {
      _pages[0] = HomeScreen(onGo: _go, refreshToken: _homeRefresh);
    }
  }

  /* Offline writes (a finished set, a logged weight) queue on the phone and
     replay when the connection is back. That queue was completely invisible:
     a trainee whose phone had no signal in the gym saw the app accept every
     set and had no idea nothing had reached the server yet. This strip is the
     honest version of that state — it appears only when something is waiting. */
  int _pending = 0;
  Timer? _pendingTimer;

  @override
  void initState() {
    super.initState();
    _pages[_i] = _buildPage(_i);
    _checkPending();
    WidgetsBinding.instance.addPostFrameCallback((_) { unawaited(_primeShell()); });
    // bootstrap واحد مشترك يغذي الاشتراك والإعلانات بدل طلبين متوازيين.
    WidgetsBinding.instance.addObserver(this); // [FIX-1] for app resume refresh
    // الاستطلاع بيبطء لوحده لما مايكونش فيه حاجة معلقة
    // قبل كده كان بيشتغل كل 20 ثانية طول اليوم حتى لو الطابور فاضي
    // دلوقتي لو مافيش حاجة معلقة بيوصل لدقيقتين ويرجع فورا لما يلاقي حاجة
    // ده بيقلل الشغل في الخلفية وبيوفر بطارية وبيمنع أي تهنيج في الواجهة
    _arm(const Duration(seconds: 20));
  }

  Duration _interval = const Duration(seconds: 20);
  static const Duration _idleMax = Duration(seconds: 120);

  void _arm(Duration d) {
    _interval = d;
    _pendingTimer?.cancel();
    _pendingTimer = Timer.periodic(d, (_) => _checkPending());
  }

  Future<void> _checkPending() async {
    final n = await Api.I.pendingOfflineCount();
    if (!mounted) return;
    if (n > 0) {
      // فيه حاجة مستنية ارجع للإيقاع السريع
      if (_interval.inSeconds != 20) _arm(const Duration(seconds: 20));
    } else if (_interval < _idleMax) {
      // الطابور فاضي بنبطء تدريجيا
      final next = _interval * 2;
      _arm(next > _idleMax ? _idleMax : next);
    }
    if (n == _pending) return;
    setState(() => _pending = n);
  }


  Future<void> _primeShell() async {
    final bootstrap = await Api.I.mobileBootstrap();
    await SubscriptionStore.I.init(seed: bootstrap.ok
        ? bootstrap.data.cast<String, dynamic>()
        : null);
    await _checkAnnouncements(result: bootstrap);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    unawaited(_checkAdminNotifications());
  }

  Future<void> _checkAnnouncements({ApiResult? result}) async {
    try {
      final r = result ?? await Api.I.mobileBootstrap();
      if (!mounted || !r.ok) return;
      final list = (r.data['announcements'] as List?)?.whereType<Map>().toList() ?? const [];
      final popups = list.where((a) => (a['mode'] == 'popup' || a['mode'] == 'both')).toList();
      if (popups.isEmpty) return;
      final sp = await SharedPreferences.getInstance();
      final seen = sp.getStringList('seen_announcements') ?? const [];
      final first = popups.firstWhere((a) => !seen.contains((a['id'] ?? '').toString()), orElse: () => <String,dynamic>{});
      if (first.isEmpty) return;
      final id = (first['id'] ?? '').toString();
      final title = (first['title'] ?? 'إعلان جديد').toString();
      final body = (first['body'] ?? '').toString();
      final link = (first['link'] ?? '').toString();
      final cta = (first['cta'] ?? 'افتح الرابط').toString();
      await NotificationService.I.showAnnouncement(title: title, body: body, link: link);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text(body, style: const TextStyle(color: AppColors.text, height: 1.5)),
          actions: [
            if (link.trim().isNotEmpty)
              FilledButton(onPressed: () { Navigator.pop(context); _openExternal(link); }, child: Text(cta)),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        ),
      );
      await sp.setStringList('seen_announcements', [...seen, id]);
    } catch (_) {}
  }

  // [Admin Notification] Check for admin-sent notifications (popup/banner)
  // called once on app start, shows unseen popup notifications
  Future<void> _checkAdminNotifications() async {
    try {
      final r = await Api.I.getAdminNotifications();
      if (!mounted || !r.ok) return;
      final items = (r.data['items'] as List?)?.whereType<Map>().toList() ?? [];
      final popups = items.where((n) => n['type'] == 'popup' || n['type'] == null).toList();
      if (popups.isEmpty) return;
      final sp = await SharedPreferences.getInstance();
      final seen = sp.getStringList('seen_admin_notifs') ?? const [];
      final first = popups.firstWhere(
        (n) => !seen.contains((n['id'] ?? '').toString()),
        orElse: () => <String, dynamic>{},
      );
      if (first.isEmpty) return;
      final id = (first['id'] ?? '').toString();
      final title = (first['title'] ?? 'إشعار جديد').toString();
      final body = (first['body'] ?? '').toString();
      final link = (first['link'] ?? '').toString();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0D1424),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.notifications_rounded, color: Color(0xFF4ADE80), size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
          ]),
          content: Text(body, style: const TextStyle(color: Color(0xFF94A3B8), height: 1.6, fontSize: 13)),
          actions: [
            if (link.trim().isNotEmpty)
              TextButton(onPressed: () { Navigator.pop(context); _openExternal(link); }, child: const Text('فتح الرابط')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4ADE80), foregroundColor: const Color(0xFF021B0F)),
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنا', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
      await sp.setStringList('seen_admin_notifs', [...seen, id]);
    } catch (_) {}
  }


  @override
  void dispose() {
    _pendingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
        super.dispose();
  }

  // [FIX-1] تحديث تلقائي عند عودة التطبيق من الخلفية
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(SubscriptionStore.I.refresh());
      if (mounted) setState(() { _homeRefresh++; _refreshHomePage(); });
    }
  }

  void _go(int i) {
    if (i < 0 || i > 3 || i == _i) return;
    setState(() {
      if (i == 0) { _homeRefresh++; _refreshHomePage(); }
      _pages[i] ??= _buildPage(i);
      _i = i;
    });
    _checkPending();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_pending > 0)
            Material(
              color: AppColors.wo.withValues(alpha: 0.16),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          size: 16, color: AppColors.wo2),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_pending تعديل لسة ماترفعش هيتزامن أول ما يرجع الإنترنت',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.wo2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _i,
              children: List<Widget>.generate(
                4, (index) => _pages[index] ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'تمرين'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'تغذية'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'حسابي'),
        ],
      ),
    );
  }
}
