// ── ElForma · models/plan_store.dart ──
// Global signal: fires whenever any plan (workout OR meal) changes on the server.
// Every screen that *displays* plan data listens to this and reloads.
// Pattern mirrors ProfileStore / SmartCoachStore: singleton ChangeNotifier.

import 'package:flutter/foundation.dart';

class PlanStore extends ChangeNotifier {
  PlanStore._();
  static final PlanStore I = PlanStore._();

  /// Call this after any successful plan save/generate (workout or meal).
  /// All listeners (HomeScreen, etc.) will automatically reload.
  Map<String, dynamic>? _completedSession;
  String? _completedOwner;
  int completionRevision = 0;
  void sessionCompleted(String? owner, Map<String, dynamic> session) {
    if (owner == null || session['status'] != 'completed') return;
    completionRevision++;
    _completedOwner = owner;
    _completedSession = Map<String, dynamic>.from(session);
    notifyListeners();
  }
  Map<String, dynamic>? completedToday(String? owner) {
    if (owner == null || owner != _completedOwner || _completedSession == null) return null;
    final at = DateTime.tryParse('${_completedSession!['finished_at'] ?? ''}')?.toLocal();
    final now = DateTime.now();
    if (at == null || at.year != now.year || at.month != now.month || at.day != now.day) return null;
    return Map<String, dynamic>.from(_completedSession!);
  }
  Map<String, dynamic> mergeCompletion(Map<String, dynamic> snapshot, String? owner) {
    final session = completedToday(owner);
    if (session == null) return snapshot;
    final merged = Map<String, dynamic>.from(snapshot);
    final rows = (snapshot['recentSessions'] is List ? snapshot['recentSessions'] as List : const [])
        .whereType<Map>().where((row) => '${row['id']}' != '${session['id']}').toList();
    merged['recentSessions'] = [session, ...rows];
    final active = snapshot['activeSession'];
    if (active is Map && '${active['id']}' == '${session['id']}') merged['activeSession'] = null;
    return merged;
  }
  void markChanged() => notifyListeners();
}
