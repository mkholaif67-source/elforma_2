// ── ElForma · models/subscription_store.dart ──
// المصدر الموحد الوحيد لحالة الاشتراك في كامل التطبيق.
// كل شاشة تستمع لهذا الـ store بدل ما تجيب بيانات الاشتراك من bootstrap مستقل.
// الهدف: تحديث لحظي فوري لكل الشاشات عند تفعيل أو انتهاء الاشتراك.
//
// الاستخدام:
//   SubscriptionStore.I.addListener(_rebuild);
//   final active = SubscriptionStore.I.active;
//   await SubscriptionStore.I.refresh();

import 'package:flutter/foundation.dart';
import '../api.dart';

class SubscriptionStore extends ChangeNotifier {
  SubscriptionStore._();
  static final SubscriptionStore I = SubscriptionStore._();

  // --- state ---------------------------------------------------------------
  bool _active = false;
  bool _isTrial = false;
  bool _canExport = false;
  bool _hasUsedTrial = false;
  String _plan = 'free';
  String? _currentPeriodEnd;
  bool _loading = false;
  bool _pollingStarted = false;

  bool get active => _active;
  bool get isTrial => _isTrial;
  bool get canExport => _canExport;
  bool get hasUsedTrial => _hasUsedTrial;
  String get plan => _plan;
  String? get currentPeriodEnd => _currentPeriodEnd;
  bool get loading => _loading;

  /// مشترك مدفوع نشط (مش تجربة)
  bool get isPaidActive => _active && !_isTrial;

  // --- boot ----------------------------------------------------------------

  /// يستدعى مرة واحدة عند بدء التطبيق (ShellScreen.initState).
  /// يجلب حالة الاشتراك ويخزنها ثم يبدأ polling كل 5 دقائق.
  Future<void> init({Map<String, dynamic>? seed}) async {
    if (seed != null) {
      applyFromBootstrap(seed);
    } else if (!_pollingStarted) {
      await refresh();
    }
    if (!_pollingStarted) {
      _pollingStarted = true;
      _startPolling();
    }
  }

  // --- refresh -------------------------------------------------------------

  /// يحدث حالة الاشتراك من السيرفر وينبه كل المستمعين فورا.
  /// استدعيه بعد أي عملية تغيير الاشتراك (تفعيل تجربة، تأكيد دفع).
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      // [FIX-TRIAL-UNLOCK] refresh() بيتنادى بعد أي تغيير في الاشتراك (تفعيل
      // تجربة/تأكيد دفع)، فلازم يجيب نسخة طازة من السيرفر مش من الكاش. قبل كده
      // كان بيقرا نسخة bootstrap متخزنة (قبل التغيير) فالمصدر الموحد يفضل
      // «مجاني» وكل الشاشات تفضل مقفولة لحد ما التطبيق يترستارت.
      final r = await Api.I.mobileBootstrap(force: true);
      if (r.ok && _applyBootstrap(r.data)) {
        notifyListeners();
      }
    } catch (_) {
      // offline — keep last known state
    } finally {
      _loading = false;
    }
  }

  bool _applyBootstrap(Map<String, dynamic> data) {
    final before = '$_active|$_isTrial|$_canExport|$_hasUsedTrial|$_plan|$_currentPeriodEnd';
    final sub = data['subscription'];
    if (sub is Map) {
      _active = sub['active'] == true;
      _isTrial = sub['isTrial'] == true;
      _canExport = sub['canExport'] == true;
      _plan = (sub['plan'] ?? 'free').toString();
      _currentPeriodEnd = sub['current_period_end']?.toString();
      // لو استخدم التجربة قبل كده (status=trialing or plan=trial even if ended)
      final status = (sub['status'] ?? '').toString();
      _hasUsedTrial = _isTrial ||
          status == 'trialing' ||
          sub['trialUsed'] == true ||
          (sub['plan'] == 'trial' && !_active);
    }
    final after = '$_active|$_isTrial|$_canExport|$_hasUsedTrial|$_plan|$_currentPeriodEnd';
    return before != after;
  }

  /// تطبيق حالة الاشتراك مباشرة من بيانات bootstrap — بدون طلب شبكة جديد.
  /// يستدعى من ShellScreen لما يجيب bootstrap أصلا.
  void applyFromBootstrap(Map<String, dynamic> bootstrapData) {
    if (_applyBootstrap(bootstrapData)) notifyListeners();
  }

  // --- polling -------------------------------------------------------------
  // [PERF] كان كل دقيقة، وكل نبضة بتنادي /api/mobile/bootstrap الكامل
  // (الجدول + الجلسات + الأوزان + المقاسات) — ده كان بيخلي التطبيق تقيل
  // ويستهلك نت طول الوقت على استضافة مجانية. 5 دقايق كفاية لحالة الاشتراك،
  // ومع كده أي شراء/تفعيل بيعمل refresh() فوري بنفسه.
  static const _pollIntervalMin = 5;

  void _startPolling() {
    Future.delayed(const Duration(minutes: _pollIntervalMin), _poll);
  }

  Future<void> _poll() async {    await refresh();
    Future.delayed(const Duration(minutes: _pollIntervalMin), _poll);
  }

  // --- clear ---------------------------------------------------------------

  void clear() {
    _active = false;
    _isTrial = false;
    _canExport = false;
    _hasUsedTrial = false;
    _plan = 'free';
    _currentPeriodEnd = null;    notifyListeners();
  }
}
