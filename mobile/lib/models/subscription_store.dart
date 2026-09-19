// Shared subscription state. Refresh only the entitlement snapshot; pause
// periodic work while backgrounded. Server remains the access authority.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:elforma/api.dart';

class SubscriptionStore extends ChangeNotifier with WidgetsBindingObserver {
  SubscriptionStore._() {
    Api.I.accountChanges.addListener(() {
      _active = false;
      _isTrial = false;
      _canExport = false;
      _hasUsedTrial = false;
      _plan = 'free';
      _currentPeriodEnd = null;
      _loading = false;
      _pollTimer?.cancel();
      if (_pollingStarted) _startPolling();
      notifyListeners();
    });
  }
  static final SubscriptionStore I = SubscriptionStore._();

  bool _active = false;
  bool _isTrial = false;
  bool _canExport = false;
  bool _hasUsedTrial = false;
  String _plan = 'free';
  String? _currentPeriodEnd;
  bool _loading = false;
  bool _pollingStarted = false;
  bool _observing = false;
  Timer? _pollTimer;

  bool get active => _active;
  bool get isTrial => _isTrial;
  bool get canExport => _canExport;
  bool get hasUsedTrial => _hasUsedTrial;
  String get plan => _plan;
  String? get currentPeriodEnd => _currentPeriodEnd;
  bool get loading => _loading;
  bool get isPaidActive => _active && !_isTrial;
  bool get _foreground => WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> init({Map<String, dynamic>? seed}) async {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
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

  Future<void> refresh() async {
    if (_loading || Api.I.accountId == null) return;
    final session = Api.I.sessionRevision;
    _loading = true;
    try {
      // Force a current entitlement read, not a cached full workout/profile.
      final r = await Api.I.mobileSubscription();
      if (session != Api.I.sessionRevision) return;
      if (r.ok && _applyBootstrap(r.data)) {
        Api.I.invalidateBootstrap();
        notifyListeners();
      }
    } catch (_) {
      // A network error is not evidence of subscription expiry.
    } finally {
      if (session == Api.I.sessionRevision) _loading = false;
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
      final status = (sub['status'] ?? '').toString();
      _hasUsedTrial = _isTrial || status == 'trialing' || sub['trialUsed'] == true ||
          (sub['plan'] == 'trial' && !_active);
    }
    final after = '$_active|$_isTrial|$_canExport|$_hasUsedTrial|$_plan|$_currentPeriodEnd';
    return before != after;
  }

  void applyFromBootstrap(Map<String, dynamic> bootstrapData) {
    if (_applyBootstrap(bootstrapData)) notifyListeners();
  }

  static const _pollIntervalMin = 5;
  void _startPolling() {
    _pollTimer?.cancel();
    if (!_pollingStarted || !_foreground || Api.I.accountId == null) return;
    _pollTimer = Timer(const Duration(minutes: _pollIntervalMin), _poll);
  }

  Future<void> _poll() async {
    if (!_foreground || Api.I.accountId == null) return;
    await refresh();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling(); // Shell refreshes once immediately on resume.
    } else {
      _pollTimer?.cancel();
    }
  }

  void clear() {
    _pollTimer?.cancel();
    _pollingStarted = false;
    _active = false;
    _isTrial = false;
    _canExport = false;
    _hasUsedTrial = false;
    _plan = 'free';
    _currentPeriodEnd = null;
    notifyListeners();
  }
}
