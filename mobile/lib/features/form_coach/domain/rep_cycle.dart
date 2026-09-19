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
    this.assessable = true,
  });

  final RepEventKind kind;
  final double amplitude;
  final int durationMs;
  final bool assessable;
}

class RepCycleSpec {
  const RepCycleSpec({
    required this.driverMetricId,
    required this.topValue,
    required this.bottomValue,
    this.enterMargin = 12,
    this.minAmplitude = 35,
    this.partialAmplitude = 18,
    this.minPhaseMs = 70,
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
  bool _reachedBottom = false;
  bool _gapInCycle = false;
  double _anchorValue = 0;
  double _extreme = 0;
  int _cycleStartMs = 0;
  int? _lastUsableMs;
  int? _lastSampleMs;
  int? _returnSinceMs;

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
    if (_lastSampleMs != null && tMs <= _lastSampleMs!) return events;
    _lastSampleMs = tMs;
    if (driver != null && !driver.isFinite) usable = false;
    final previousUsable = _lastUsableMs;
    if (previousUsable != null && tMs - previousUsable > FcTuning.repAbortGapMs) {
      final event = interrupt(tMs);
      if (event != null) events.add(event);
    }

    if (!usable || driver == null) {
      if (_inCycle) _gapInCycle = true;
      _pendingZone = null;
      _returnSinceMs = null;
      _phase = RepPhase.unknown;
      return events;
    }

    _lastUsableMs = tMs;
    _driverValue = driver;

    final _Zone candidate = _zoneOf(driver);
    if (_inCycle && candidate == _Zone.top) {
      _returnSinceMs ??= tMs;
    } else {
      _returnSinceMs = null;
    }
    // The first trusted frame is an anchor, not a transition. Applying the
    // persistence gate to it leaves a stream that starts at the top unanchored
    // and loses the first valid rep (and makes reset depend on old state).
    final bool firstTrustedSample = _previousDriver == null;
    if (firstTrustedSample) {
      _zone = candidate;
      _pendingZone = candidate;
      _pendingSinceMs = tMs;
    } else {
      if (candidate != _pendingZone) {
        _pendingZone = candidate;
        _pendingSinceMs = tMs;
      }
      if (candidate != _zone && tMs - _pendingSinceMs >= spec.minPhaseMs) {
        _zone = candidate;
      }
    }

    final double? previous = _previousDriver;
    if (previous != null) {
      final double delta = driver - previous;
      if (delta.abs() > 0.4) {
        _towardBottom = spec.descending ? delta < 0 : delta > 0;
      }
    }
    _previousDriver = driver;

    if (_zone == _Zone.top && candidate == _Zone.top) {
      if (_inCycle) {
        final double amplitude = (_anchorValue - _extreme).abs();
        // Waiting at the endpoint confirms persistence, not movement duration.
        final int duration = (_returnSinceMs ?? tMs) - _cycleStartMs;
        final int minCommitMs = math.max(spec.noiseFloorMs, FcTuning.hardMinRepMs);
        _inCycle = false;
        _lastAmplitude = amplitude;
        if (_gapInCycle && amplitude >= spec.partialAmplitude) {
          events.add(RepEvent(kind: RepEventKind.cycleAborted,
            amplitude: amplitude, durationMs: duration, assessable: false));
        } else if (!_gapInCycle &&
            _reachedBottom &&
            duration >= minCommitMs &&
            amplitude >= spec.minAmplitude) {
          _reps++;
          _lastRepDurationMs = duration;
          events.add(RepEvent(
            kind: RepEventKind.repCompleted,
            amplitude: amplitude,
            durationMs: duration,
          ));
        } else if (!_gapInCycle &&
            duration >= spec.noiseFloorMs &&
            amplitude >= spec.partialAmplitude) {
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

    // Start as soon as the trusted stream leaves the top candidate. The stable
    // zone may remain top for minPhaseMs, but it must not re-anchor the cycle
    // to a middle sample while that transition is settling.
    if (!_inCycle && _anchored && candidate != _Zone.top) {
      _inCycle = true;
      _reachedBottom = false;
      _gapInCycle = false;
      _cycleStartMs = tMs;
      _extreme = driver;
    }

    if (_inCycle) {
      if (_zone == _Zone.bottom) _reachedBottom = true;
      final bool deeper = spec.descending ? driver < _extreme : driver > _extreme;
      if (deeper) _extreme = driver;

      // A fast rep may cross the bottom zone for less than minPhaseMs. Full
      // ROM is still a strong guard, so remember the excursion on the crossing
      // instead of requiring a visible pause at the endpoint.
      if (candidate == _Zone.bottom &&
          (_anchorValue - driver).abs() >= spec.minAmplitude) {
        _reachedBottom = true;
      }

      _phase = _zone == _Zone.bottom
          ? RepPhase.bottom
          : (_towardBottom ? RepPhase.towardBottom : RepPhase.towardTop);

      if (tMs - _cycleStartMs > spec.maxRepMs) {
        final amplitude = cycleAmplitude;
        if (amplitude >= spec.partialAmplitude) {
          events.add(RepEvent(kind: RepEventKind.cycleAborted,
            amplitude: amplitude, durationMs: tMs - _cycleStartMs,
            assessable: !_gapInCycle));
        }
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

  /// Surface evidence of motion once, without judging an unseen movement.
  RepEvent? interrupt(int tMs) {
    final amplitude = cycleAmplitude;
    final event = _inCycle && amplitude >= spec.partialAmplitude
        ? RepEvent(kind: RepEventKind.cycleAborted, amplitude: amplitude,
            durationMs: math.max(0, tMs - _cycleStartMs), assessable: false)
        : null;
    abortCycle();
    return event;
  }

  /// Drops the in-flight rep without touching the counters.
  void abortCycle() {
    _inCycle = false;
    _reachedBottom = false;
    _gapInCycle = false;
    _anchored = false;
    _extreme = _anchorValue;
    _previousDriver = null;
    _lastUsableMs = null;
    _returnSinceMs = null;
    _pendingZone = null;
    _zone = _Zone.middle;
    _phase = RepPhase.unknown;
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
    _reachedBottom = false;
    _gapInCycle = false;
    _anchorValue = 0;
    _extreme = 0;
    _cycleStartMs = 0;
    _lastUsableMs = null;
    _lastSampleMs = null;
    _returnSinceMs = null;
    _zone = _Zone.middle;
    _pendingZone = null;
    _pendingSinceMs = 0;
    _towardBottom = true;
  }
}
