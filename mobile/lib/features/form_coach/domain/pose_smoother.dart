// Form Coach - jitter reduction.
//
// Raw landmarks jitter by a few degrees even when the user is still, which would
// create phantom errors. A heavy EMA would hide the jitter but add lag that skews
// phase timing and rep counting, so we use a One Euro filter: strong smoothing
// while still, fast response while moving.
//
// Occlusion: when a point drops below the hard floor we hold its last known
// position for the overlay while letting its confidence decay, so rules treat it
// as untrustworthy instead of following a snapping point.

import 'dart:math' as math;

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/fc_tuning.dart';

class OneEuroFilter {
  OneEuroFilter({
    this.minCutoff = FcTuning.smoothMinCutoff,
    this.beta = FcTuning.smoothBeta,
    this.derivativeCutoff = FcTuning.smoothDerivativeCutoff,
  });

  final double minCutoff;
  final double beta;
  final double derivativeCutoff;

  double? _value;
  double _derivative = 0;

  double filter(double value, double dtSeconds) {
    final double? previous = _value;
    if (previous == null || dtSeconds <= 0) {
      _value = value;
      _derivative = 0;
      return value;
    }
    final double rawDerivative = (value - previous) / dtSeconds;
    final double alphaDerivative = _alpha(derivativeCutoff, dtSeconds);
    _derivative = alphaDerivative * rawDerivative + (1 - alphaDerivative) * _derivative;

    final double cutoff = minCutoff + beta * _derivative.abs();
    final double alpha = _alpha(cutoff, dtSeconds);
    final double filtered = alpha * value + (1 - alpha) * previous;
    _value = filtered;
    return filtered;
  }

  static double _alpha(double cutoff, double dtSeconds) {
    final double tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dtSeconds);
  }

  void reset() {
    _value = null;
    _derivative = 0;
  }
}

class _LandmarkFilters {
  _LandmarkFilters()
      : x = OneEuroFilter(),
        y = OneEuroFilter(),
        z = OneEuroFilter();

  final OneEuroFilter x;
  final OneEuroFilter y;
  final OneEuroFilter z;

  double? smoothedVisibility;
  FcPoint? lastKnown;

  void reset() {
    x.reset();
    y.reset();
    z.reset();
    smoothedVisibility = null;
    lastKnown = null;
  }
}

class PoseSmoother {
  PoseSmoother({this.visibilityAlpha = FcTuning.visibilitySmoothingAlpha});

  final double visibilityAlpha;

  final Map<FcLandmark, _LandmarkFilters> _filters = <FcLandmark, _LandmarkFilters>{};
  int? _lastTimestampMs;

  PoseSample smooth(PoseSample sample) {
    final int? previousMs = _lastTimestampMs;
    final double dt = previousMs == null
        ? 1 / FcTuning.targetAnalysisFps
        : math.max(1, sample.timestampMs - previousMs) / 1000.0;
    _lastTimestampMs = sample.timestampMs;

    final Map<FcLandmark, FcPoint> output = <FcLandmark, FcPoint>{};

    for (final FcLandmark landmark in FcLandmark.values) {
      final FcPoint? raw = sample.points[landmark];
      if (raw == null) continue;
      final _LandmarkFilters filters =
          _filters.putIfAbsent(landmark, () => _LandmarkFilters());

      final double previousVisibility = filters.smoothedVisibility ?? raw.visibility;
      final double visibility =
          visibilityAlpha * raw.visibility + (1 - visibilityAlpha) * previousVisibility;
      filters.smoothedVisibility = visibility;

      if (raw.visibility < FcTuning.landmarkHardFloor) {
        final FcPoint? held = filters.lastKnown;
        output[landmark] = (held ?? raw).copyWith(visibility: visibility);
        continue;
      }

      final FcPoint smoothed = FcPoint(
        x: filters.x.filter(raw.x, dt),
        y: filters.y.filter(raw.y, dt),
        z: filters.z.filter(raw.z, dt),
        visibility: visibility,
      );
      filters.lastKnown = smoothed;
      output[landmark] = smoothed;
    }

    return PoseSample(timestampMs: sample.timestampMs, points: output);
  }

  void reset() {
    for (final _LandmarkFilters filters in _filters.values) {
      filters.reset();
    }
    _filters.clear();
    _lastTimestampMs = null;
  }
}
