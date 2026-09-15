import 'package:elforma/community_links.dart';
import 'package:elforma/widgets/forma_design.dart';
// ── ElForma · screens/shell_screen.dart ──
// Bottom-navigation shell that hosts the main tabs.
// الهيكل السفلي للتبويبات.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elforma/api.dart';
import 'package:elforma/models/announcement_store.dart';
import 'package:elforma/theme.dart';
import 'package:elforma/widgets/announcement_card.dart';
import 'package:elforma/background_poll.dart';
import 'package:elforma/push_service.dart';
import 'package:elforma/screens/home_screen.dart';
import 'package:elforma/screens/meal_plan_screen.dart';
import 'package:elforma/screens/workout_screen.dart';
import 'package:elforma/screens/account_screen.dart';
import 'package:elforma/models/subscription_store.dart';

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

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return HomeScreen(onGo: _go, refreshToken: _homeRefresh);
      case 1: return const WorkoutScreen();
      case 2: return const MealPlanScreen();
      default: return const AccountScreen();
    }
  }

  void _accountReset(){
    if(!mounted)return;
    setState((){_i=0;_pages.fillRange(0,_pages.length,null);_pages[0]=_buildPage(0);});
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
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    CommunityLinks.shellReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => CommunityLinks.flush());
    _pages[_i] = _buildPage(_i);
    _checkPending();
    AnnouncementStore.I.start();
    Api.I.accountChanges.addListener(_accountReset);
    unawaited(PushService.I.start());
    // This is a *network* poll and it runs for as long as the app is open, on
    // every screen, because the shell is never disposed. At 30s that was 120
    // requests an hour: radio wakeups are one of the most expensive things a
    // phone does, and this alone is enough to feel like background heat.
    // Admin notifications are not time-critical, so 2 minutes is plenty — and
    // didChangeAppLifecycleState already refreshes once immediately on resume.
    _notificationTimer = Timer.periodic(const Duration(seconds: 120), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) unawaited(_checkAdminNotifications());
    });
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
    unawaited(_checkAdminNotifications()); // [PERF] removed artificial 250 ms delay
  }

  Future<void> _checkAnnouncements({ApiResult? result}) async {
    try {
      final r = result ?? await Api.I.mobileBootstrap();
      if (!mounted || !r.ok) return;
      final list = (r.data['announcements'] as List?)?.whereType<Map>().toList() ?? const [];
      final popups = list.where((a) => (a['mode'] == 'popup' || a['mode'] == 'both')).toList();
      if (popups.isEmpty) return;
      final sp = await SharedPreferences.getInstance();
      final seen = sp.getStringList('seen_announcements:${Api.I.accountId}') ?? const [];
      final first = popups.firstWhere((a) => !seen.contains((a['id'] ?? '').toString()), orElse: () => <String,dynamic>{});
      if (first.isEmpty) return;
      final id = (first['id'] ?? '').toString();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: AppColors.card,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnnouncementCard(data: {...Map<String, dynamic>.from(first), 'dismissible': false},onUnavailable:(){if(ModalRoute.of(dialogContext)?.isCurrent==true)Navigator.of(dialogContext).pop();}),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('إغلاق')),
          ])),
        ),
      );
      await sp.setStringList('seen_announcements:${Api.I.accountId}', [...seen, id]);
    } catch (_) {}
  }

  // [Admin Notification] Check for admin-sent notifications (popup/banner)
  // called once on app start, shows unseen popup notifications
  Future<void> _checkAdminNotifications() async {
    try { await BackgroundPoll.runOnce(); } catch (_) {}
  }


  @override
  void dispose() {
    CommunityLinks.shellReady = false;
    _pendingTimer?.cancel();
    _notificationTimer?.cancel();
    AnnouncementStore.I.stop();
    Api.I.accountChanges.removeListener(_accountReset);
    WidgetsBinding.instance.removeObserver(this);
        super.dispose();
  }

  // [FIX-1] تحديث تلقائي عند عودة التطبيق من الخلفية
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state==AppLifecycleState.resumed){AnnouncementStore.I.start();}else{AnnouncementStore.I.stop();}
    if (state == AppLifecycleState.resumed) {
      unawaited(PushService.I.refreshToken());
      unawaited(_checkAdminNotifications());
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
                      const FormaIcon(Icons.cloud_off_rounded,
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
                4, (index) => TickerMode(enabled: index == _i, child: _pages[index] ?? const SizedBox.shrink()),
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
              icon: FormaIcon(Icons.home_outlined),
              selectedIcon: FormaIcon(Icons.home_rounded),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: FormaIcon(Icons.fitness_center_rounded),
              selectedIcon: FormaIcon(Icons.fitness_center_rounded),
              label: 'تمرين'),
          NavigationDestination(
              icon: FormaIcon(Icons.restaurant_rounded),
              selectedIcon: FormaIcon(Icons.restaurant_rounded),
              label: 'تغذية'),
          NavigationDestination(
              icon: FormaIcon(Icons.person_outline_rounded),
              selectedIcon: FormaIcon(Icons.person_rounded),
              label: 'حسابي'),
        ],
      ),
    );
  }
}
