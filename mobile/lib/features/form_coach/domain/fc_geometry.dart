// Form Coach - stateless geometry. Missing input always yields null, never a
// fabricated value. Distances are divided by body scale (torso length) so they
// are unitless ratios instead of pixel values.

import 'dart:math' as math;

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';

class FcGeometry {
  const FcGeometry._();

  static const double _radToDeg = 180 / math.pi;

  static double distance(FcPoint a, FcPoint b) {
    final double dx = a.x - b.x;
    final double dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  static FcPoint midpoint(FcPoint a, FcPoint b) => FcPoint(
        x: (a.x + b.x) / 2,
        y: (a.y + b.y) / 2,
        z: (a.z + b.z) / 2,
        visibility: math.min(a.visibility, b.visibility),
      );

  /// Angle at b, in degrees (0..180).
  static double? angleAt(FcPoint? a, FcPoint? b, FcPoint? c) {
    if (a == null || b == null || c == null) return null;
    return angleBetweenVectors(a.x - b.x, a.y - b.y, c.x - b.x, c.y - b.y);
  }

  static double? angleBetweenVectors(double x1, double y1, double x2, double y2) {
    final double n1 = math.sqrt(x1 * x1 + y1 * y1);
    final double n2 = math.sqrt(x2 * x2 + y2 * y2);
    if (n1 < 1e-6 || n2 < 1e-6) return null;
    final double cos = ((x1 * x2 + y1 * y2) / (n1 * n2)).clamp(-1.0, 1.0);
    return math.acos(cos) * _radToDeg;
  }

  static double? angleBetweenSegments(FcPoint? a, FcPoint? b, FcPoint? c, FcPoint? d) {
    if (a == null || b == null || c == null || d == null) return null;
    return angleBetweenVectors(b.x - a.x, b.y - a.y, d.x - c.x, d.y - c.y);
  }

  /// Tilt of a->b from vertical. Positive = leaning towards frame right.
  static double? signedTiltFromVertical(FcPoint? a, FcPoint? b) {
    if (a == null || b == null) return null;
    final double dx = b.x - a.x;
    final double dy = b.y - a.y;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return null;
    return math.atan2(dx, -dy) * _radToDeg; // image y grows downwards
  }

  static double? tiltFromVertical(FcPoint? a, FcPoint? b) =>
      signedTiltFromVertical(a, b)?.abs();

  /// Torso axis as [hip, shoulder]; falls back to the single visible side.
  static List<FcPoint>? torsoAxis(PoseSample sample, {double minVisibility = 0.2}) {
    final FcPoint? shoulder = _midOrSingle(
        sample, FcLandmark.leftShoulder, FcLandmark.rightShoulder, minVisibility);
    final FcPoint? hip =
        _midOrSingle(sample, FcLandmark.leftHip, FcLandmark.rightHip, minVisibility);
    if (shoulder == null || hip == null) return null;
    return <FcPoint>[hip, shoulder];
  }

  /// Body scale = torso length (fallback: shoulder width * 1.6).
  /// Also used as a distance-from-camera proxy.
  static double? bodyScale(PoseSample sample, {double minVisibility = 0.2}) {
    final List<FcPoint>? axis = torsoAxis(sample, minVisibility: minVisibility);
    if (axis != null) {
      final double torso = distance(axis[0], axis[1]);
      if (torso > 1e-3) return torso;
    }
    final FcPoint? ls = sample.point(FcLandmark.leftShoulder, minVisibility: minVisibility);
    final FcPoint? rs = sample.point(FcLandmark.rightShoulder, minVisibility: minVisibility);
    if (ls != null && rs != null) {
      final double width = distance(ls, rs);
      if (width > 1e-3) return width * 1.6;
    }
    return null;
  }

  /// shoulder width / body scale: front vs side camera-angle proxy.
  static double? shoulderSpreadRatio(PoseSample sample, {double minVisibility = 0.2}) =>
      _spreadRatio(sample, FcLandmark.leftShoulder, FcLandmark.rightShoulder, minVisibility);

  static double? hipSpreadRatio(PoseSample sample, {double minVisibility = 0.2}) =>
      _spreadRatio(sample, FcLandmark.leftHip, FcLandmark.rightHip, minVisibility);

  static double mean(Iterable<double> values) {
    double sum = 0;
    int count = 0;
    for (final double value in values) {
      sum += value;
      count++;
    }
    if (count == 0) return 0;
    return sum / count;
  }

  /// Median: baselines must survive a few bad frames.
  static double? median(List<double> values) {
    if (values.isEmpty) return null;
    final List<double> sorted = List<double>.of(values)..sort();
    final int middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static FcPoint? _midOrSingle(
    PoseSample sample,
    FcLandmark left,
    FcLandmark right,
    double minVisibility,
  ) {
    final FcPoint? a = sample.point(left, minVisibility: minVisibility);
    final FcPoint? b = sample.point(right, minVisibility: minVisibility);
    if (a != null && b != null) return midpoint(a, b);
    return a ?? b;
  }

  static double? _spreadRatio(
    PoseSample sample,
    FcLandmark left,
    FcLandmark right,
    double minVisibility,
  ) {
    final FcPoint? a = sample.point(left, minVisibility: minVisibility);
    final FcPoint? b = sample.point(right, minVisibility: minVisibility);
    if (a == null || b == null) return null;
    final double? scale = bodyScale(sample, minVisibility: minVisibility);
    if (scale == null || scale <= 1e-3) return null;
    return distance(a, b) / scale;
  }
}
