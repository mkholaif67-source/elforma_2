// Form Coach - movement phases and rep counting.
//
// One driver measurement per exercise defines the movement. A rep is a closed
// loop: top zone -> excursion -> back to top zone. Credit is only given on the
// return, and the anchor resets immediately, which is what prevents double
// counting. Protections: zone changes must persist (minPhaseMs), short
// excursions become partial reps, very short cycles are treated as noise, a pose
// gap aborts the in-flight rep, and stale cycles are abandoned.

import 'dart:math' as math;

import 'package:elforma/features/form_coach/domain/fc_tuning.dart';

enum RepPhase { unknown, top, towardBottom, bottom, towardTop }

String repPhaseAr(RepPhase phase) {
  switch (phase) {
    case RepPhase.unknown:
      return '—';
    case RepPhase.top:
      return 'البداية';
    case RepPhase.towardBottom:
      return 'نزول';
    case RepPhase.bottom:
      return 'النهاية';
    case RepPhase.towardTop:
      return 'رجوع';
  }
}

enum RepEventKind { repCompleted, partialRep, cycleAborted }

class RepEvent {
  const RepEvent({
    required this.kind,
    required this.amplitude,
    required this.durationMs,
  });

  final RepEventKind kind;
  final double amplitude;
  final int durationMs;
}

class RepCycleSpec {
  const RepCycleSpec({
    required this.driverMetricId,
    required this.topValue,
    required this.bottomValue,
    this.enterMargin = 12,
    this.minAmplitude = 35,
    this.partialAmplitude = 18,
    this.minPhaseMs = 110,
    this.noiseFloorMs = 300,
    this.maxRepMs = 15000,
    this.topLabelAr = '',
    this.bottomLabelAr = '',
  });

  final String driverMetricId;

  /// Driver value at the start position and at the far end of the movement.
  final double topValue;
  final double bottomValue;

  final double enterMargin;
  final double minAmplitude;
  final double partialAmplitude;
  final int minPhaseMs;
  final int noiseFloorMs;
  final int maxRepMs;
  final String topLabelAr;
  final String bottomLabelAr;

  bool get descending => bottomValue < topValue;
  double get fullRange => (topValue - bottomValue).abs();
  double get expectedMin => math.min(topValue, bottomValue);
  double get expectedMax => math.max(topValue, bottomValue);
}

enum _Zone { top, middle, bottom }

class RepCounter {
  RepCounter(this.spec);

  final RepCycleSpec spec;

  int _reps = 0;
  int _partials = 0;
  RepPhase _phase = RepPhase.unknown;
  double? _driverValue;
  double? _previousDriver;
  double _lastAmplitude = 0;
  int _lastRepDurationMs = 0;

  bool _anchored = false;
  bool _inCycle = false;
  double _anchorValue = 0;
  double _extreme = 0;
  int _cycleStartMs = 0;
  int? _lastUsableMs;

  _Zone _zone = _Zone.middle;
  _Zone? _pendingZone;
  int _pendingSinceMs = 0;
  bool _towardBottom = true;

  int get reps => _reps;
  int get partials => _partials;
  RepPhase get phase => _phase;
  double? get driverValue => _driverValue;
  double get lastAmplitude => _lastAmplitude;
  int get lastRepDurationMs => _lastRepDurationMs;
  bool get inCycle => _inCycle;

  double get cycleAmplitude => _inCycle ? (_anchorValue - _extreme).abs() : 0;

  double get cycleProgress {
    if (!_inCycle || spec.fullRange <= 0) return 0;
    return (cycleAmplitude / spec.fullRange).clamp(0.0, 1.0);
  }

  List<RepEvent> update({
    required int tMs,
    required double? driver,
    required bool usable,
  }) {
    final List<RepEvent> events = <RepEvent>[];

    if (!usable || driver == null) {
      final int? lastUsable = _lastUsableMs;
      if (_inCycle && lastUsable != null && tMs - lastUsable > FcTuning.repAbortGapMs) {
        events.add(RepEvent(
          kind: RepEventKind.cycleAborted,
          amplitude: cycleAmplitude,
          durationMs: tMs - _cycleStartMs,
        ));
        abortCycle();
      }
      _phase = RepPhase.unknown;
      return events;
    }

    _lastUsableMs = tMs;
    _driverValue = driver;

    final _Zone candidate = _zoneOf(driver);
    if (candidate != _pendingZone) {
      _pendingZone = candidate;
      _pendingSinceMs = tMs;
    }
    if (candidate != _zone && tMs - _pendingSinceMs >= spec.minPhaseMs) {
      _zone = candidate;
    }

    final double? previous = _previousDriver;
    if (previous != null) {
      final double delta = driver - previous;
      if (delta.abs() > 0.4) {
        _towardBottom = spec.descending ? delta < 0 : delta > 0;
      }
    }
    _previousDriver = driver;

    if (_zone == _Zone.top) {
      if (_inCycle) {
        final double amplitude = (_anchorValue - _extreme).abs();
        final int duration = tMs - _cycleStartMs;
        _inCycle = false;
        _lastAmplitude = amplitude;
        if (duration >= math.max(spec.noiseFloorMs, FcTuning.hardMinRepMs) &&
            amplitude >= spec.minAmplitude) {
          _reps++;
          _lastRepDurationMs = duration;
          events.add(RepEvent(
            kind: RepEventKind.repCompleted,
            amplitude: amplitude,
            durationMs: duration,
          ));
        } else if (duration >= spec.noiseFloorMs && amplitude >= spec.partialAmplitude) {
          _partials++;
          events.add(RepEvent(
            kind: RepEventKind.partialRep,
            amplitude: amplitude,
            durationMs: duration,
          ));
        }
      }
      _anchored = true;
      _anchorValue = driver;
      _extreme = driver;
      _cycleStartMs = tMs;
      _phase = RepPhase.top;
      return events;
    }

    if (!_inCycle && _anchored) {
      _inCycle = true;
      _cycleStartMs = tMs;
      _extreme = driver;
    }

    if (_inCycle) {
      final bool deeper = spec.descending ? driver < _extreme : driver > _extreme;
      if (deeper) _extreme = driver;

      _phase = _zone == _Zone.bottom
          ? RepPhase.bottom
          : (_towardBottom ? RepPhase.towardBottom : RepPhase.towardTop);

      if (tMs - _cycleStartMs > spec.maxRepMs) {
        events.add(RepEvent(
          kind: RepEventKind.cycleAborted,
          amplitude: cycleAmplitude,
          durationMs: tMs - _cycleStartMs,
        ));
        abortCycle();
        _phase = RepPhase.unknown;
      }
    } else {
      // Started mid-movement: we never saw the top, so the phase is unknown.
      _phase = RepPhase.unknown;
    }

    return events;
  }

  _Zone _zoneOf(double value) {
    if (spec.descending) {
      if (value >= spec.topValue - spec.enterMargin) return _Zone.top;
      if (value <= spec.bottomValue + spec.enterMargin) return _Zone.bottom;
    } else {
      if (value <= spec.topValue + spec.enterMargin) return _Zone.top;
      if (value >= spec.bottomValue - spec.enterMargin) return _Zone.bottom;
    }
    return _Zone.middle;
  }

  /// Drops the in-flight rep without touching the counters.
  void abortCycle() {
    _inCycle = false;
    _anchored = false;
    _extreme = _anchorValue;
  }

  void reset() {
    _reps = 0;
    _partials = 0;
    _phase = RepPhase.unknown;
    _driverValue = null;
    _previousDriver = null;
    _lastAmplitude = 0;
    _lastRepDurationMs = 0;
    _anchored = false;
    _inCycle = false;
    _anchorValue = 0;
    _extreme = 0;
    _cycleStartMs = 0;
    _lastUsableMs = null;
    _zone = _Zone.middle;
    _pendingZone = null;
    _pendingSinceMs = 0;
    _towardBottom = true;
  }
}
