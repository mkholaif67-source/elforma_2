// ── ElForma · screens/home_screen.dart ──
// Home dashboard: quick status + entry points; opens onboarding when profile is empty.
// الرئيسية: ملخص ومداخل سريعة.

import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/offline_banner.dart';
import '../widgets/announcement_card.dart';
import 'profile_setup_screen.dart';
import 'training_session_screen.dart';
import 'progress_screen.dart';
import 'pricing_screen.dart';
import '../models/smart_coach_store.dart';
import '../models/profile_store.dart';
import '../models/plan_store.dart';
import '../models/subscription_store.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) onGo;

  /// بيتزود من ال shell كل ما المستخدم يرجع للرئيسية. التبويبات محفوظة
  /// جوا IndexedStack ف initState مابيتنداهاش تاني، ومن غير ده كانت الرئيسية
  /// تفضل شايفة «أنشئ جدولي» رغم إن الجدول اتعمل فعلا.
  final int refreshToken;
  const HomeScreen({super.key, required this.onGo, this.refreshToken = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};
  int _loadGeneration = 0;

  Map<String, dynamic>? get user => _map(data['user']);
  Map<String, dynamic>? get profile => _map(data['profile']);
  Map<String, dynamic>? get subscription => _map(data['subscription']);
  Map<String, dynamic>? get activeSession => _map(data['activeSession']);
  Map<String, dynamic>? get nutrition => _map(data['nutritionToday']);
  List get sessions => data['recentSessions'] is List ? data['recentSessions'] as List : const [];
  List get weights => data['weights'] is List ? data['weights'] as List : const [];

  Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  num _number(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    // لو المستخدم فعل/قفل «المتابعة الذكية» من الحساب لازم الرئيسية تتحدث
    // فورا حتى وهي محفوظة جوا IndexedStack.
    SmartCoachStore.I.addListener(_onCoachToggle);
    ProfileStore.I.addListener(_onDataChanged); // profile updates
    PlanStore.I.addListener(_onDataChanged);      // workout/meal plan updates
    SubscriptionStore.I.addListener(_onSubChanged); // [FIX-1]
    _load();
  }

  void _onCoachToggle() {
    if (mounted) setState(() {});
  }

  void _onSubChanged() { if (mounted) _load(); } // shared bootstrap, no forced duplicate

  void _onDataChanged() {
    // Called when ProfileStore or PlanStore notifies (workout/meal plan changed)
    if (mounted) _load(force: true);
  }

  @override
  void dispose() {
    SmartCoachStore.I.removeListener(_onCoachToggle);
    ProfileStore.I.removeListener(_onDataChanged);
    PlanStore.I.removeListener(_onDataChanged);
    SubscriptionStore.I.removeListener(_onSubChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load(force: true);
  }

  Future<void> _load({bool force = false}) async {
    final generation = ++_loadGeneration;
    // [FIX] لو عندنا بيانات قديمة، نفضل نعرضها وبنحدث في الخلفية بدون spinner.
    // بس في أول تحميل (data فاضية) بنظهر loading صح.
    final firstLoad = data.isEmpty;
    if (mounted && firstLoad) setState(() { loading = true; error = null; });
    final response = await Api.I.mobileBootstrap(force: force);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      loading = false;
      if (response.ok) {
        data = response.data;
        error = null;
      } else if (firstLoad) {
        // أول تحميل فشل: اعرض رسالة الخطأ
        error = response.error.isNotEmpty ? response.error : 'تعذر تحميل يومك';
      }
      // لو مش أول تحميل وفيه error: نفضل نعرض البيانات القديمة بدون نقول للمستخدم
    });
  }

  Future<void> _profileSetup() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ProfileSetupScreen(initial: profile),
    ));
    if (changed == true) await _load();
  }

  Map<String, dynamic>? _activeWorkoutDay() {
    final session = activeSession;
    final workoutPlan = _map(data['workoutPlan']);
    final plan = _map(workoutPlan?['data']);
    if (session == null || plan == null) return null;
    final wanted = (session['day_key'] ?? '').toString();
    final candidates = <Map<String, dynamic>>[];
    void add(dynamic value) {
      if (value is Map) candidates.add(Map<String, dynamic>.from(value));
      if (value is List) {
        for (final item in value.whereType<Map>()) {
          candidates.add(Map<String, dynamic>.from(item));
        }
      }
    }
    add(plan['previewDay']);
    add(plan['trainDays']);
    add(plan['plan']);
    for (final day in candidates) {
      final key = (day['key'] ?? day['name'] ?? '').toString();
      if (key == wanted || day['name']?.toString() == session['day_name']?.toString()) {
        return day;
      }
    }
    return null;
  }

  Future<void> _resumeWorkout() async {
    final day = _activeWorkoutDay();
    if (day == null) {
      widget.onGo(1);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TrainingSessionScreen(day: day),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(child: Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.nu,
          onRefresh: _load,
          child: loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.nu))
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                  children: [
                    _header(),
                    ..._announcementCards(),
                    if (error != null) ...[const SizedBox(height: 16), _errorCard()],
                    const SizedBox(height: 20),
                    // [OWNER-RULE] بانر التجربة المجانية — يظهر تلقائيا طول ما الحساب في
                    // وضع التجربة، ويختفي لوحده لما تخلص التجربة أو يبقى اشتراك مدفوع.
                    if (subscription?['isTrial'] == true) ...[
                      _trialBanner(),
                      const SizedBox(height: 14),
                    ],
                    // [OWNER-RULE] هدية 3 أيام مجانية — تظهر للي لسه ماخدش التجربة،
                    // ويقدر يفعلها بضغطة من الشاشة الرئيسية.
                    if (_showTrialGift()) ...[
                      _trialGiftBanner(),
                      const SizedBox(height: 14),
                    ],
                    if (profile == null || profile!['onboardingComplete'] != true) ...[
                      _profileBanner(),
                      const SizedBox(height: 14),
                    ],
                    if (activeSession != null) ...[
                      _activeWorkout(),
                      const SizedBox(height: 14),
                    ] else ...[
                      _nextWorkout(),
                      const SizedBox(height: 14),
                    ],
                    _coachCard(),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _nutritionCard()),
                      const SizedBox(width: 11),
                      Expanded(child: _waterCard()),
                    ]),
                    const SizedBox(height: 14),
                    _weeklyProgress(),
                    const SizedBox(height: 14),
                    _weightCard(),
                  ],
                ),
        ),
      ),
    ));
  }


  List<Widget> _announcementCards() {
    final list = (data['announcements'] is List ? data['announcements'] as List : const []);
    final rows = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((a) {
      final p = (a['placement'] ?? 'both').toString();
      return p == 'both' || p == 'home';
    }).where((a) => (a['mode'] ?? 'card').toString() == 'card' || (a['mode'] ?? '').toString() == 'both').toList();
    if (rows.isEmpty) return const <Widget>[];
    final cards = <Widget>[
      // خط فاصل أنيق بين المحتوى العلوي والبانر
      Padding(
        padding: const EdgeInsets.only(bottom: 14, top: 4),
        child: Row(children: [
          Expanded(child: Divider(color: AppColors.line.withValues(alpha: .5), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('إعلانات',
                style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Divider(color: AppColors.line.withValues(alpha: .5), thickness: 1)),
        ]),
      ),
    ];
    cards.addAll(rows.map((a) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AnnouncementCard(data: a),
    )));
    return cards;
  }

  Widget _header() {
    final name = (user?['name'] ?? '').toString().trim();
    final pro = subscription?['active'] == true;
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name.isEmpty ? 'أهلا بيك' : 'أهلا $name',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(_todayMessage(), style: const TextStyle(color: AppColors.muted)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: pro ? AppColors.nu.withValues(alpha: .14) : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: pro ? AppColors.nu.withValues(alpha: .3) : AppColors.line),
        ),
        child: Text(pro ? 'PRO' : 'مجاني',
            style: TextStyle(color: pro ? AppColors.nu : AppColors.muted,
                fontWeight: FontWeight.w900, fontSize: 11)),
      ),
    ]);
  }

  String _todayMessage() {
    if (activeSession != null) return 'عندك جلسة بدأت بالفعل كمل من مكانك';
    if (profile == null) return 'نبدأ بضبط خطتك على جسمك وهدفك';
    return 'دي أهم خطوات يومك بدون أي تشتيت';
  }

  Widget _profileBanner() => InkWell(
        onTap: _profileSetup,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.nu.withValues(alpha: .18), AppColors.card]),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppColors.nu.withValues(alpha: .35)),
          ),
          child: const Row(children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.nu, size: 29),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('جهز خطتك الشخصية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              SizedBox(height: 4),
              Text('4 خطوات قصيرة تجمع بيانات التدريب والتغذية مرة واحدة',
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.45)),
            ])),
            Icon(Icons.chevron_left_rounded, color: AppColors.nu),
          ]),
        ),
      );

  // بانر احترافي بصياغة تسويقية يوضح إن الحساب مفعل بالكامل مجانا لمدة 3 أيام.
  // [FIX-2] slim active-trial strip
  Widget _trialBanner() {
    final sub = SubscriptionStore.I;
    String label = 'حسابك حاليا في تجربة مجانية';
    if (sub.currentPeriodEnd != null) {
      try {
        final end = DateTime.parse(sub.currentPeriodEnd!);
        final rem = end.difference(DateTime.now()).inDays;
        if (rem > 0) label = 'تجربتك المجانية تنتهي خلال $rem يوم';
        else label = 'تجربتك انتهت!';
      } catch (_) {}
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PricingScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: .35)),
        ),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 9),
          Expanded(child: Text(label,
              style: const TextStyle(color: Color(0xFF10B981),
                  fontWeight: FontWeight.w700, fontSize: 13))),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF10B981), size: 18),
        ]),
      ),
    );
  }

  // [OWNER-RULE] هدية الـ 3 أيام تتاح لأي حساب لسه ماخدش تجربة قبل كده ومالوش
  // اشتراك فعال دلوقتي — بتختفي للأبد أول ما يفعلها أو يشترك.
  bool _showTrialGift() {
    final sub = subscription;
    if (sub == null) return false;
    if (sub['trialUsed'] == true) return false;
    if (sub['isTrial'] == true) return false;
    if (sub['active'] == true) return false;
    return true;
  }

  bool _giftBusy = false;
  Future<void> _activateTrialGift() async {
    if (_giftBusy) return;
    setState(() => _giftBusy = true);
    try {
      final res = await Api.I.startTrial();
      if (!mounted) return;
      if (!res.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.friendlyError('حصل خطأ، جرب تاني'))));
        return;
      }
      // [FIX-TRIAL-SYNC] The trial used to update only this screen data.
      // Account / Workout / Nutrition read SubscriptionStore, so they kept
      // showing "free" and stayed locked until the app was restarted.
      // Refreshing the single source of truth notifies every screen now.
      // [FIX-TRIAL-UNLOCK] فرغ الكاش الأول بعدين حدث المصدر الموحد بنسخة
      // طازة. الترتيب القديم (refresh قبل invalidate) كان بيخلي refresh يقرا
      // نسخة قبل التجربة فيفضل الحساب «مجاني/مقفول».
      Api.I.invalidateBootstrap();
      await SubscriptionStore.I.refresh();
      PlanStore.I.markChanged();
      await _load(force: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تفعيل هديتك: 3 أيام مجانا ')));
    } finally {
      if (mounted) setState(() => _giftBusy = false);
    }
  }

    Widget _trialGiftBanner() => InkWell(
        onTap: _giftBusy ? null : _activateTrialGift,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.nu.withValues(alpha: .22), AppColors.card],
            ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppColors.nu.withValues(alpha: .38)),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.nu.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.card_giftcard_rounded,
                  color: AppColors.nu, size: 26),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('هديتك: 3 أيام مجانا بكامل المميزات',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('فعل تجربتك المجانية دلوقتي واستمتع بكل مميزات التطبيق',
                      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _giftBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.nu))
                : Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.nu.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.nu.withValues(alpha: .35)),
                    ),
                    child: const Text('فعل',
                        style: TextStyle(
                            color: AppColors.nu,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                  ),
          ]),
        ),
      );

  Widget _activeWorkout() {
    // [FIX-DONE-BTN] لو جلسة النهارده خلصت مابنرجعش لواجهة التمرين تاني.
    if (_isTodayCompleted()) return _completedHero();
    final session = activeSession!;
    final done = (session['sets'] is List)
        ? (session['sets'] as List).where((s) => s is Map && (s['completed'] == 1 || s['completed'] == true)).length
        : 0;
    return _actionCard(
      color: AppColors.wo,
      icon: Icons.play_circle_fill_rounded,
      eyebrow: 'جلسة جارية الآن',
      title: _cleanDayName((session['day_name'] ?? 'تمرين اليوم').toString()),
      subtitle: done > 0 ? 'أنجزت $done مجموعات كمل من مكانك' : 'الجلسة محفوظة ومستعدة للاستكال',
      button: 'استكمل جلسة اليوم',
      onTap: _resumeWorkout,
      // [FIX-DONE-BTN] زرار «تم الانتهاء» موجود أصلا (بند 15) لكن كان متركب
      // على كارت البداية بس؛ ولما الجلسة تبقى شغالة الكارت بيتغير فكان يختفي.
      secondaryButton: 'تم الانتهاء',
      secondaryIcon: Icons.check_rounded,
      onSecondary: _quickCompleteActive,
    );
  }

  // [FIX-DONE-BTN] بيقفل الجلسة الشغالة نفسها وبس: مفيش جلسة جديدة، مفيش
  // تغيير في الجدول، مفيش أيام جاية بتتأثر، والضغطة التانية مابتعملش حاجة.
  Future<void> _quickCompleteActive() async {
    if (_quickBusy) return;
    if (_isTodayCompleted()) return;
    final sid = (activeSession?['id'] as num?)?.toInt();
    if (sid == null) return;
    setState(() => _quickBusy = true);
    try {
      final finished = await Api.I.finishWorkoutSession(sid, 0, 'إنهاء سريع من الهوم');
      if (!mounted) return;
      if (!finished.ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(finished.friendlyError('تعذر إنهاء الجلسة حاول تاني'))));
        return;
      }
      final now = DateTime.now();
      _completedLocalDay =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      Api.I.invalidateBootstrap();
      PlanStore.I.markChanged();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم تسجيل تمرين النهارده ')));
      await _load(force: true);
    } finally {
      if (mounted) setState(() => _quickBusy = false);
    }
  }

  /// [UI-COMPLETION] حالة «تمرين اليوم مكتمل» — UI بس، مبنية على نفس
  /// _isTodayCompleted() الموجودة، فبتفضل باقي اليوم وترجع طبيعي أول يوم جديد.
  Widget _completedHero() {
    const green = Color(0xFF35D07F);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF12402F), Color(0xFF0A2419)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: green.withValues(alpha: .42)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
                color: green.withValues(alpha: .18), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: green, size: 32),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تم الانتهاء من تمرين اليوم ',
                  style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w900)),
              SizedBox(height: 5),
              Text('جلسة اليوم مكتملة — أحسنت! ',
                  style: TextStyle(
                      color: green, fontWeight: FontWeight.w800, fontSize: 13.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 13),
        const Text(
          'التزامك النهارده هو الفرق بين الكلام والنتيجة. ريح عضلاتك، كمل أكلك وميتك، وبكرة نكمل.',
          style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.55),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: green,
              side: BorderSide(color: green.withValues(alpha: .55)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: () => widget.onGo(1),
            child: const Text('شوف جدول الأسبوع'),
          ),
        ),
      ]),
    );
  }

  // كل أيام الجدول المفعل بالترتيب (المحرك بيرجع 7 أيام جوا plan).
  List<Map<String, dynamic>> _planDays() {
    final workoutPlan = _map(data['workoutPlan']);
    final planData = _map(workoutPlan?['data']);
    if (planData == null) return const [];
    final raw = planData['plan'] ?? planData['days'] ?? planData['trainDays'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((day) => Map<String, dynamic>.from(day))
        .toList();
  }

  bool get _hasPlan => _planDays().isNotEmpty;

  /// يوم النهاردة من الجدول. الأسبوع عندنا بيبدأ السبت، وDateTime.weekday
  /// بترجع الاثنين=1 .. الأحد=7، عشان كده بنزحق ب (weekday % 7) − السبت.
  Map<String, dynamic>? _todayPlanDay() {
    final days = _planDays();
    if (days.isEmpty) return null;
    // [FIX-PLAN-RESET] نحسب موضع اليوم من تاريخ تفعيل الجدول — مش من اليوم في الأسبوع.
    // كده لو المتدرب بدل الجدول هيبدأ دايما من اليوم الأول بدون ما يكمل من نفس الـindex.
    final workoutPlan = _map(data['workoutPlan']);
    final planData = _map(workoutPlan?['data']);
    final scheduleStart = planData?['_scheduleStartDate']?.toString();
    final createdAtStr = scheduleStart ?? workoutPlan?['createdAt']?.toString();
    if (createdAtStr != null && createdAtStr.isNotEmpty) {
      try {
        final activationDate = DateTime.parse(createdAtStr).toLocal();
        final today = DateTime.now();
        final todayMidnight = DateTime(today.year, today.month, today.day);
        final activationMidnight = DateTime(activationDate.year, activationDate.month, activationDate.day);
        final daysSince = todayMidnight.difference(activationMidnight).inDays.clamp(0, 10000);
        return days[daysSince % days.length];
      } catch (_) {}
    }
    // fallback قديم لو مافيش createdAt
    final weekday = DateTime.now().weekday;
    final saturdayBased = (weekday + 1) % 7;
    if (saturdayBased >= days.length) return days[saturdayBased % days.length];
    return days[saturdayBased];
  }



  /// يشيل أي وصف عضلي أو تفصيلة بعد الاسم الأساسي للجدول/اليوم.
  /// مثال: "Lower 1 — كوادز Squat عزل" → "Lower 1"
  String _cleanDayName(String name) {
    for (final sep in [' — ', ' – ', ' - ', ' / ', ' | ']) {
      final i = name.indexOf(sep);
      if (i > 0) return name.substring(0, i).trim();
    }
    return name;
  }
  bool _isRestDay(Map<String, dynamic> day) {
    final exercises = day['exercises'];
    final name = '${day['name'] ?? ''}';
    if (name.contains('راحة') || name.toLowerCase().contains('rest')) return true;
    return !(exercises is List && exercises.isNotEmpty);
  }


  // [FIX] هل أكمل المستخدم جلسة تمرين اليوم بالفعل؟
  // يعتمد على finished_at فقط — لو الجلسة شغالة (started بس مش finished)
  // مش بتتحسب "خلصت" وزرار "تم الانتهاء" لازم يفضل ظاهر.
  // [FIX-INSTANT-DONE] الحالة بتبقى مكتملة فورا من غير ريفرش.
  String? _completedLocalDay;

  bool _isTodayCompleted() {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    if (_completedLocalDay == todayStr) return true;
    return sessions.whereType<Map>().any((raw) {
      final v = raw['finished_at'] ?? '';   // [FIX] لا نعتبر started_at = اكتمال
      if ((v as String).isEmpty) return false;
      final d = DateTime.tryParse('$v');
      if (d == null) return false;
      final ds = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      return ds == todayStr;
    });
  }

  bool _pendingWorkoutStart() {
    final workoutPlan = _map(data['workoutPlan']);
    final planData = _map(workoutPlan?['data']);
    final raw = planData?['_firstWorkoutDate']?.toString();
    if (raw == null || raw.isEmpty) return false;
    try {
      final first = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day)
          .isBefore(DateTime(first.year, first.month, first.day));
    } catch (_) { return false; }
  }

  Map<String, dynamic>? _firstScheduledWorkout() {
    final workoutPlan = _map(data['workoutPlan']);
    final planData = _map(workoutPlan?['data']);
    final rawFirst = planData?['_firstWorkoutDate']?.toString();
    final rawStart = planData?['_scheduleStartDate']?.toString();
    final days = _planDays();
    if (rawFirst == null || rawStart == null || days.isEmpty) return null;
    try {
      final first = DateTime.parse(rawFirst).toLocal();
      final start = DateTime.parse(rawStart).toLocal();
      final index = DateTime(first.year, first.month, first.day)
          .difference(DateTime(start.year, start.month, start.day)).inDays % days.length;
      return days[index];
    } catch (_) { return null; }
  }

  String _firstWorkoutWeekday() {
    final workoutPlan = _map(data['workoutPlan']);
    final planData = _map(workoutPlan?['data']);
    final raw = planData?['_firstWorkoutDate']?.toString();
    if (raw == null) return '';
    try {
      const names = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      return names[DateTime.parse(raw).toLocal().weekday - 1];
    } catch (_) { return ''; }
  }

  Widget _nextWorkout() {
    // مافيش جدول فعلا نعرض الإنشاء. غير كده الزرار ده مايظهرش تاني.
    if (!_hasPlan) {
      return _actionCard(
        color: AppColors.wo,
        icon: Icons.fitness_center_rounded,
        eyebrow: 'تمرين اليوم',
        title: 'صمم جدولك التدريبي',
        subtitle: 'برنامج مناسب لهدفك ووقتك وإصاباتك',
        button: 'صمم جدولك',
        onTap: () => widget.onGo(1),
      );
    }

    if (_pendingWorkoutStart()) {
      final first = _firstScheduledWorkout();
      final weekday = _firstWorkoutWeekday();
      final name = first == null
          ? 'أول جلسة'
          : _cleanDayName((first['name'] ?? 'أول جلسة').toString());
      return _actionCard(
        color: AppColors.wo,
        icon: Icons.event_available_rounded,
        eyebrow: 'بداية الجدول',
        title: weekday.isEmpty ? 'أول جلسة جاهزة' : 'بدايتك يوم $weekday',
        subtitle: '$name — أول حصة في التقسيمة',
        button: 'عرض أول جلسة',
        onTap: () => widget.onGo(1),
      );
    }

    // لو المستخدم أكمل جلسة اليوم → اعرض كارت اكتملت.
    if (_isTodayCompleted()) return _completedHero();

    final day = _todayPlanDay();
    if (day == null || _isRestDay(day)) {
      return _actionCard(
        color: const Color(0xFF8BA8FF),
        icon: Icons.bedtime_rounded,
        eyebrow: 'النهاردة',
        title: 'يوم التعافي — إنت لسه على الطريق',
        subtitle:
            'الراحة بتبني قوتك: حركة خفيفة، مية كفاية، ونوم هادئ',
        button: 'افتح يوم التعافي',
        onTap: () => widget.onGo(1),
      );
    }

    // [FIX-TODAY-CARD] الكارت بيعرف نفسه باسم الجدول ويوم التمرين فورا.
    final planKey = (_map(data['workoutPlan'])?['key'] ?? '').toString();
    final exercises = (day['exercises'] as List).length;
    // [OWNER-RULE] اسم الجدول فقط بدون تصنيفات العضلات (Glutes إلخ).
    // [بند 15] زرار "تم الانتهاء" السريع جنب زرار البدء — للتمرين فقط.
    return _actionCard(
      color: AppColors.wo,
      icon: Icons.fitness_center_rounded,
      eyebrow: planKey.isEmpty ? 'تمرين النهاردة' : 'جدولك: $planKey',
      title: _cleanDayName((day['name'] ?? 'تمرين اليوم').toString()),
      subtitle: '$exercises تمرين جاهزين ليك',
      button: 'ابدأ جلسة اليوم',
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TrainingSessionScreen(day: day),
        ));
        await _load();
      },
      secondaryButton: 'تم الانتهاء',
      secondaryIcon: Icons.check_rounded,
      onSecondary: () => _quickComplete(day),
    );
  }

  // [بند 15] إنهاء سريع لتمرين النهاردة من الهوم: نبدأ الجلسة
  // (أو نكمل الشغالة) ثم نقفلها فورا من غير ما ندخل شاشة التمرين.
  bool _quickBusy = false;
  Future<void> _quickComplete(Map<String, dynamic> day) async {
    if (_quickBusy) return;
    if (_isTodayCompleted()) return; // ضغطة تانية بعد الاكتمال = مفيش تأثير زيادة
    setState(() => _quickBusy = true);
    try {
      final dayKey =
          (day['key'] ?? day['dayKey'] ?? day['name'] ?? '').toString();
      final dayName = _cleanDayName((day['name'] ?? 'تمرين اليوم').toString());
      final start = await Api.I.startWorkoutSession(dayKey, dayName);
      if (!mounted) return;
      if (!start.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حصل خطأ، جرب تاني')));
        return;
      }
      // [FIX-IDEMPOTENT-1] لو جلسة اليوم مكتملة خلاص مابنبعتش إنهاء تاني.
      void markToday() {
        final now = DateTime.now();
        _completedLocalDay =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      }
      if (start.data['alreadyCompleted'] == true) {
        markToday();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تمرين النهاردة متسجل خلاص ')));
        await _load();
        return;
      }
      final session = start.data['session'];
      final sid = session is Map ? (session['id'] as num?)?.toInt() : null;
      if (sid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حصل خطأ، جرب تاني')));
        return;
      }
      final finished = await Api.I.finishWorkoutSession(sid, 0, 'إنهاء سريع من الهوم');
      if (!mounted) return;
      if (!finished.ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(finished.friendlyError('تعذر إنهاء الجلسة حاول تاني'))));
        return;
      }
      markToday();
      Api.I.invalidateBootstrap();
      PlanStore.I.markChanged();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استكمال تمرين النهاردة ')));
      await _load(force: true);
    } finally {
      if (mounted) setState(() => _quickBusy = false);
    }
  }

  // ملخص اليوم: سعرات النهاردة مقابل الهدف + الالتزام + التغير في الوزن + توجيه واحد واضح.
  /// [ONE-CALORIE] رقم واحد للسعرات في كل الصفحات.
  /// المفتاح المعتمد في السيرفر وفي صفحة التغدية هو targetCals، والهوم كان
  /// بيدور على أسماء مابتوصلش خالص → فكان بيعرض صفر أو رقم مختلف.
  int get _targetCalories {
    final value = profile?['targetCals'] ??
        profile?['targetCalories'] ??
        _map(data['nutritionTargets'])?['targetCals'] ??
        profile?['calories'] ??
        profile?['dailyCalories'];
    return _number(value).round();
  }

  int get _eatenCalories {
    return _number(nutrition?['calories']).round();
  }

  int get _weekDone {
    final list = sessions;
    final since = DateTime.now().subtract(const Duration(days: 7));
    var count = 0;
    for (final item in list.whereType<Map>()) {
      final raw = '${item['finished_at'] ?? item['started_at'] ?? ''}';
      final parsed = DateTime.tryParse(raw);
      if (parsed != null && parsed.isAfter(since)) count++;
    }
    return count;
  }

  int get _weekTarget {
    final value = _number(profile?['trainingDays']).round();
    return value <= 0 ? 4 : value;
  }

  /// فرق الوزن بين أول وآخر قياس مسجل، وموجب يعني زيادة.
  double? get _weightDelta {
    final list = weights;
    if (list.length < 2) return null;
    final values = list
        .whereType<Map>()
        .map((item) => _number(item['weight_kg'] ?? item['weight']))
        .whereType<num>()
        .toList();
    if (values.length < 2) return null;
    return (values.first - values.last).toDouble();
  }

  String _coachLine() {
    final target = _targetCalories;
    final eaten = _eatenCalories;
    final done = _weekDone;
    final needed = _weekTarget;
    if (done == 0) {
      return 'ماسجلتش تمرين الأسبوع ده لسة. حصة واحدة النهاردة ترجعك على المسار';
    }
    if (done >= needed) {
      return 'قفلت تمارين الأسبوع كلها. خليك على الأكل والنوم والنتيجة هتبان';
    }
    if (target > 0 && eaten > target + 200) {
      return 'عديت سعراتك النهاردة ب ${eaten - target} سعرة. قلل الكارب في آخر وجبة وزود المية';
    }
    if (target > 0 && eaten > 0 && eaten < target * 0.6) {
      return 'لسة ناقصك ${target - eaten} سعرة النهاردة. الأكل القليل بيوقف النتيجة مش يسرعها';
    }
    return 'ماشي صح. فاضلك ${needed - done} حصة عشان تقفل الأسبوع';
  }

  Widget _coachCard() {
    // «المتابعة الذكية» متحكم فيها من تاب الحساب.
    if (!SmartCoachStore.I.enabled) return const SizedBox.shrink();
    final target = _targetCalories;
    final eaten = _eatenCalories;
    final delta = _weightDelta;
    final adherence =
        _weekTarget == 0 ? 0 : ((_weekDone / _weekTarget) * 100).clamp(0, 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.insights_rounded, color: AppColors.nu, size: 19),
          SizedBox(width: 7),
          Text('ملخص النهاردة',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        ]),
        const SizedBox(height: 13),
        Row(children: [
          Expanded(
              child: _stat(
                  'سعرات اليوم',
                  target > 0 ? '$eaten / $target' : '$eaten',
                  target > 0 && eaten > target ? AppColors.wo2 : AppColors.nu)),
          Expanded(child: _stat('الالتزام', '$adherence%', AppColors.nu2)),
          Expanded(
              child: _stat(
                  'التغير في الوزن',
                  delta == null
                      ? '—'
                      : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} كجم',
                  delta == null ? AppColors.muted : const Color(0xFFFFC857))),
        ]),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.nu.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(_coachLine(),
              style: const TextStyle(fontSize: 12, height: 1.6)),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      );

  Widget _actionCard({required Color color, required IconData icon, required String eyebrow,
      required String title, required String subtitle, required String button, required VoidCallback onTap,
      String? secondaryButton, IconData? secondaryIcon, VoidCallback? onSecondary}) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: .20), AppColors.card]),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: color.withValues(alpha: .34)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 43, height: 43, decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(eyebrow, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ])),
          ]),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 14),
          if (secondaryButton == null)
            SizedBox(width: double.infinity, height: 47, child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              child: Text(button, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ))
          else
            Row(children: [
              Expanded(child: SizedBox(height: 47, child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(backgroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                child: Text(button, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ))),
              const SizedBox(width: 9),
              SizedBox(height: 47, child: OutlinedButton(
                onPressed: _quickBusy ? null : onSecondary,
                child: Text(secondaryButton, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: color.withValues(alpha: .12),
                  side: BorderSide(color: color.withValues(alpha: .70), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
              )),
            ]),
        ]),
      );

  Widget _nutritionCard() {
    final calories = _number(nutrition?['calories']);
    final meals = nutrition?['meals'] is List ? nutrition!['meals'] as List : const [];
    return _smallCard(
      color: AppColors.nu,
      icon: Icons.restaurant_menu_rounded,
      title: 'التغذية',
      value: calories > 0 ? '${calories.round()} سعرة' : 'ابدأ يومك',
      subtitle: meals.isEmpty ? 'خطتك ووجباتك' : '${meals.length} وجبات مسجلة',
      onTap: () => widget.onGo(2),
    );
  }

  Widget _waterCard() {
    final water = _number(nutrition?['waterMl']);
    final percent = ((water / 2500) * 100).clamp(0, 100).round();
    return _smallCard(
      color: const Color(0xFF42A5F5),
      icon: Icons.water_drop_rounded,
      title: 'المياه',
      value: water > 0 ? '${(water / 1000).toStringAsFixed(1)} لتر' : '0.0 لتر',
      subtitle: '$percent% من هدف 2.5 لتر',
      onTap: () => widget.onGo(2),
    );
  }

  Widget _smallCard({required Color color, required IconData icon, required String title,
      required String value, required String subtitle, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: color, size: 21), const SizedBox(width: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))]),
            const SizedBox(height: 13),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 10.5)),
          ]),
        ),
      );

  Widget _weeklyProgress() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    // [FIX-WEEK-DISTINCT] تقدم الأسبوع = عدد الأيام المكتملة، مش عدد السجلات.
    final seenDays = <String>{};
    for (final raw in sessions) {
      if (raw is! Map) continue;
      final value = raw['finished_at'];
      if (value == null || '$value'.isEmpty) continue;
      final date = DateTime.tryParse('$value');
      if (date == null || !date.isAfter(weekStart.subtract(const Duration(seconds: 1)))) continue;
      seenDays.add('${date.year}-${date.month}-${date.day}');
    }
    final count = seenDays.length;
    final target = profile?['trainingDays'] is num ? (profile!['trainingDays'] as num).toInt() : 3;
    final progress = (count / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.insights_rounded, color: AppColors.wo2),
          const SizedBox(width: 9),
          const Expanded(child: Text('تقدم التدريب هذا الأسبوع', style: TextStyle(fontWeight: FontWeight.w900))),
          Text('$count / $target', style: const TextStyle(color: AppColors.wo2, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(9), color: AppColors.wo, backgroundColor: AppColors.line),
      ]),
    );
  }

  Widget _weightCard() {
    final latest = weights.isNotEmpty && weights.first is Map ? weights.first as Map : null;
    final current = _number(latest?['weight']);
    final profileWeight = _number(profile?['weight']);
    final shown = current > 0 ? current : profileWeight;
    final target = _number(profile?['targetWeight']);
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ProgressScreen(),
        ));
        await _load();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
        child: Row(children: [
          const Icon(Icons.monitor_weight_outlined, color: AppColors.nu, size: 26),
          const SizedBox(width: 11),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الوزن والمتابعة', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 3),
            Text('الوزن والقياسات واتجاه التقدم', style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ])),
          Text(shown > 0 ? '${shown.toStringAsFixed(1)} كجم' : 'سجل وزنك',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          if (target > 0) Text(' → ${target.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.nu, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.red.withValues(alpha: .25))),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.wo2),
          const SizedBox(width: 9),
          Expanded(child: Text(error!, style: const TextStyle(color: AppColors.muted))),
          TextButton(onPressed: _load, child: const Text('حاول تاني')),
        ]),
      );
}
