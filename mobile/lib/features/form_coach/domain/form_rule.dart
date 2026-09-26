// Form Coach - form rules with tolerance, persistence and consistency.
//
// A rule never fires from one frame. To fire, all of these must hold:
//  1) pose usable, 2) movement in an applicable phase, 3) measurement exists with
//  confidence >= minConfidence, 4) value outside [min-tolerance, max+tolerance],
//  5) stayed outside for persistenceMs, 6) at least minConsistency of the frames
//  in that window were violating, 7) rule not in cooldown / per-set budget left,
//  8) no other cue inside the global cue cooldown (allowFire).
//
// That is what replaces naive checks like "error > 20% = wrong".

import 'package:elforma/features/form_coach/domain/fc_tuning.dart';
import 'package:elforma/features/form_coach/domain/metric_spec.dart';
import 'package:elforma/features/form_coach/domain/rep_cycle.dart';

enum RuleSeverity { critical, major, minor }

class FormRule {
  const FormRule({
    required this.id,
    required this.metricId,
    required this.cueAr,
    this.detailAr = '',
    this.min,
    this.max,
    this.tolerance = 0,
    this.phases = const <RepPhase>[],
    this.persistenceMs = 450,
    this.minConsistency = FcTuning.defaultMinConsistency,
    this.minConfidence = FcTuning.ruleMinConfidence,
    this.priority = 5,
    this.severity = RuleSeverity.major,
    this.cooldownMs = FcTuning.defaultRuleCooldownMs,
    this.maxFiresPerSet = FcTuning.defaultMaxFiresPerSet,
    this.measuresAr = '',
  });

  final String id;
  final String metricId;
  final String cueAr;
  final String detailAr;

  /// Accepted range; null side = unbounded.
  final double? min;
  final double? max;

  /// Slack on top of the range: normal variation between people.
  final double tolerance;

  /// Phases where the rule is meaningful. Empty = all phases.
  final List<RepPhase> phases;

  final int persistenceMs;
  final double minConsistency;
  final double minConfidence;

  /// Lower number = more important when several errors compete.
  final int priority;
  final RuleSeverity severity;
  final int cooldownMs;
  final int maxFiresPerSet;

  /// What this rule actually measures (debug panel + report).
  final String measuresAr;

  bool appliesTo(RepPhase phase) => phases.isEmpty || phases.contains(phase);

  double violationMagnitude(double value) {
    final double? low = min == null ? null : min! - tolerance;
    final double? high = max == null ? null : max! + tolerance;
    if (low != null && value < low) return low - value;
    if (high != null && value > high) return value - high;
    return 0;
  }
}

class FormRuleState {
  const FormRuleState({
    required this.ruleId,
    required this.evaluable,
    required this.value,
    required this.confidence,
    required this.magnitude,
    required this.violationMs,
    required this.consistency,
    required this.candidate,
    required this.fired,
    required this.firesThisSet,
    required this.blockedReason,
  });

  final String ruleId;
  final bool evaluable;
  final double? value;
  final double confidence;
  final double magnitude;
  final int violationMs;
  final double consistency;

  /// Violating and persistent but not spoken (cooldown / budget / global gate).
  final bool candidate;
  final bool fired;
  final int firesThisSet;

  /// pose | phase | no-metric | low-confidence | persistence | consistency |
  /// max-fires | cooldown | global-cooldown
  final String blockedReason;
}

class FormRuleTracker {
  FormRuleTracker(this.rule);

  final FormRule rule;

  int _fires = 0;
  int? _violationSinceMs;
  int? _lastViolationMs;
  int? _lastFiredMs;
  int? _lastSampleMs;
  final List<List<double>> _window = <List<double>>[];

  int get fires => _fires;

  FormRuleState update({
    required int tMs,
    required MetricReading? reading,
    required RepPhase phase,
    required bool poseUsable,
    bool allowFire = true,
  }) {
    if (_lastSampleMs != null && tMs <= _lastSampleMs!) {
      return _blocked(reading, 'timestamp');
    }
    if (_lastSampleMs != null && tMs - _lastSampleMs! > 250) resetWindow();
    _lastSampleMs = tMs;
    String blocked = '';
    if (!poseUsable) {
      blocked = 'pose';
    } else if (!rule.appliesTo(phase)) {
      blocked = 'phase';
    } else if (reading == null) {
      blocked = 'no-metric';
    } else if (!reading.value.isFinite ||
        !reading.confidence.isFinite ||
        reading.confidence < rule.minConfidence) {
      blocked = 'low-confidence';
    }

    if (blocked.isNotEmpty) {
      resetWindow();
      return FormRuleState(
        ruleId: rule.id,
        evaluable: false,
        value: reading?.value,
        confidence: reading?.confidence ?? 0,
        magnitude: 0,
        violationMs: 0,
        consistency: 0,
        candidate: false,
        fired: false,
        firesThisSet: _fires,
        blockedReason: blocked,
      );
    }

    final MetricReading value = reading!;
    final double magnitude = rule.violationMagnitude(value.value);
    final bool violating = magnitude > 0;

    _window.add(<double>[tMs.toDouble(), violating ? 1 : 0]);
    while (_window.isNotEmpty && tMs - _window.first[0] > rule.persistenceMs) {
      _window.removeAt(0);
    }

    if (violating) {
      final int? lastViolation = _lastViolationMs;
      if (_violationSinceMs == null ||
          (lastViolation != null &&
              tMs - lastViolation > FcTuning.violationStreakGapMs)) {
        _violationSinceMs = tMs;
      }
      _lastViolationMs = tMs;
    } else {
      final int? lastViolation = _lastViolationMs;
      if (lastViolation != null &&
          tMs - lastViolation > FcTuning.violationStreakGapMs) {
        _violationSinceMs = null;
      }
    }

    final int violationMs =
        _violationSinceMs == null ? 0 : tMs - _violationSinceMs!;
    double consistency = 0;
    if (_window.isNotEmpty) {
      double sum = 0;
      for (final List<double> entry in _window) {
        sum += entry[1];
      }
      consistency = sum / _window.length;
    }

    bool candidate = false;
    bool fired = false;
    if (violating && violationMs >= rule.persistenceMs) {
      if (consistency < rule.minConsistency) {
        blocked = 'consistency';
      } else {
        candidate = true;
        final int? lastFired = _lastFiredMs;
        if (_fires >= rule.maxFiresPerSet) {
          blocked = 'max-fires';
        } else if (lastFired != null && tMs - lastFired < rule.cooldownMs) {
          blocked = 'cooldown';
        } else if (!allowFire) {
          blocked = 'global-cooldown';
        } else {
          fired = true;
          commitFire(tMs);
        }
      }
    } else if (violating) {
      blocked = 'persistence';
    }

    return FormRuleState(
      ruleId: rule.id,
      evaluable: true,
      value: value.value,
      confidence: value.confidence,
      magnitude: magnitude,
      violationMs: violationMs,
      consistency: consistency,
      candidate: candidate,
      fired: fired,
      firesThisSet: _fires,
      blockedReason: blocked,
    );
  }

  // Called only for the arbitration winner when update(allowFire: false) is used.
  bool commitFire(int tMs) {
    if (_fires >= rule.maxFiresPerSet ||
        (_lastFiredMs != null && tMs - _lastFiredMs! < rule.cooldownMs))
      return false;
    _fires++;
    _lastFiredMs = tMs;
    // Keep observation continuity: a spoken cue must not erase error evidence.
    return true;
  }

  FormRuleState _blocked(MetricReading? reading, String reason) =>
      FormRuleState(
        ruleId: rule.id,
        evaluable: false,
        value: reading?.value,
        confidence: reading?.confidence ?? 0,
        magnitude: 0,
        violationMs: 0,
        consistency: 0,
        candidate: false,
        fired: false,
        firesThisSet: _fires,
        blockedReason: reason,
      );

  void resetWindow() {
    _violationSinceMs = null;
    _lastViolationMs = null;
    _window.clear();
  }

  void resetSet() {
    resetWindow();
    _fires = 0;
    _lastFiredMs = null;
    _lastSampleMs = null;
  }
}
