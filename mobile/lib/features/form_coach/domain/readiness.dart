// Form Coach - setup / ready check.
//
// Nothing is judged until the camera actually sees what the profile needs:
// required joints visible, body inside the frame, sane distance, the required
// camera view, and good enough landmark quality. The user is given ONE short
// instruction at a time (the highest-priority issue), never a checklist.

import 'package:elforma/features/form_coach/domain/fc_geometry.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/fc_tuning.dart';

enum PreferredView { front, side, any }

/// Declaration order = priority order for what we tell the user.
enum ReadinessIssue {
  noPerson,
  partialBody,
  outOfFrame,
  tooFar,
  tooClose,
  wrongViewSide,
  wrongViewFront,
  lowConfidence,
  lowLight,
  cameraMoving,
  lowFps,
}

String readinessCueAr(ReadinessIssue issue) {
  switch (issue) {
    case ReadinessIssue.noPerson:
      return 'مش شايف حد — اظهر قدام الكاميرا';
    case ReadinessIssue.partialBody:
      return 'خلي المفاصل المطلوبة ظاهرة في الكاميرا';
    case ReadinessIssue.outOfFrame:
      return 'ارجع لوسط الكادر';
    case ReadinessIssue.tooFar:
      return 'قرّب الهاتف شوية';
    case ReadinessIssue.tooClose:
      return 'ابعد الهاتف قليلًا';
    case ReadinessIssue.wrongViewSide:
      return 'ضع الهاتف جانبك — التصوير من الجنب';
    case ReadinessIssue.wrongViewFront:
      return 'خلي الكاميرا قدامك مباشرة';
    case ReadinessIssue.lowConfidence:
      return 'خلي جسمك واضح قدام الكاميرا';
    case ReadinessIssue.lowLight:
      return 'الإضاءة ضعيفة — زوّد النور';
    case ReadinessIssue.cameraMoving:
      return 'ثبّت الهاتف';
    case ReadinessIssue.lowFps:
      return 'الجهاز مضغوط — اقفل تطبيقات تانية';
  }
}

class ReadinessSpec {
  const ReadinessSpec({
    required this.requiredJoints,
    this.requireBothSides = false,
    this.view = PreferredView.any,
    this.requireConfirmedView = false,
    this.minVisibility = FcTuning.landmarkMinVisibility,
    this.minTorsoFraction = 0.16,
    this.maxTorsoFraction = 0.55,
    this.frameMargin = FcTuning.readyFrameMargin,
    this.stableMs = FcTuning.readyStableMs,
    this.checkLighting = true,
  });

  final List<FcJoint> requiredJoints;

  /// true: both sides needed (front-view work). false: one visible side is enough.
  final bool requireBothSides;

  final PreferredView view;
  final bool requireConfirmedView;
  final double minVisibility;

  /// Torso length as a fraction of the frame: our distance proxy.
  final double minTorsoFraction;
  final double maxTorsoFraction;

  final double frameMargin;
  final int stableMs;
  final bool checkLighting;
}

class ReadinessReport {
  const ReadinessReport({
    required this.ok,
    required this.issues,
    required this.progress,
    required this.torsoFraction,
    required this.spreadRatio,
    required this.meanVisibility,
    required this.detectedView,
    required this.unknown,
  });

  static const ReadinessReport unknownReport = ReadinessReport(
    ok: false,
    issues: <ReadinessIssue>[ReadinessIssue.noPerson],
    progress: 0,
    torsoFraction: null,
    spreadRatio: null,
    meanVisibility: 0,
    detectedView: PreferredView.any,
    unknown: true,
  );

  final bool ok;
  final List<ReadinessIssue> issues;

  /// 0..1 progress of the "hold this position" timer.
  final double progress;

  final double? torsoFraction;
  final double? spreadRatio;
  final double meanVisibility;
  final PreferredView detectedView;
  final bool unknown;

  ReadinessIssue? get primaryIssue => issues.isEmpty ? null : issues.first;

  String get cueAr {
    final ReadinessIssue? issue = primaryIssue;
    if (issue == null) return 'تمام — ثبّت شوية';
    return readinessCueAr(issue);
  }
}

class ReadinessEvaluator {
  ReadinessEvaluator(this.spec);

  final ReadinessSpec spec;

  ReadinessReport _last = ReadinessReport.unknownReport;
  int? _okSinceMs;

  ReadinessReport get last => _last;

  ReadinessReport update({
    required PoseSample? sample,
    required int tMs,
    double? luma,
    double fps = 0,
    bool subjectUnstable = false,
  }) {
    if (sample == null || sample.isEmpty) {
      _okSinceMs = null;
      return _last = ReadinessReport.unknownReport;
    }

    final List<ReadinessIssue> issues = <ReadinessIssue>[];
    final List<FcLandmark> used = <FcLandmark>[];
    bool missing = false;
    double sideConfidence(FcSide side) => sample.confidenceOf(
        spec.requiredJoints.map((joint) => fcLandmarkFor(joint, side)));
    final visibleSide =
        sideConfidence(FcSide.left) >= sideConfidence(FcSide.right)
            ? FcSide.left
            : FcSide.right;

    for (final FcJoint joint in spec.requiredJoints) {
      final FcPoint? left = sample.joint(joint, FcSide.left);
      final FcPoint? right = sample.joint(joint, FcSide.right);
      final bool leftOk = left != null && left.visibility >= spec.minVisibility;
      final bool rightOk =
          right != null && right.visibility >= spec.minVisibility;

      if (spec.requireBothSides) {
        if (!leftOk || !rightOk) {
          missing = true;
        } else {
          used.add(fcLandmarkFor(joint, FcSide.left));
          used.add(fcLandmarkFor(joint, FcSide.right));
        }
      } else {
        if ((visibleSide == FcSide.left && !leftOk) ||
            (visibleSide == FcSide.right && !rightOk)) {
          missing = true;
        } else {
          used.add(fcLandmarkFor(joint, visibleSide));
        }
      }
    }

    if (missing) issues.add(ReadinessIssue.partialBody);

    final FcBounds? bounds = used.isEmpty ? null : sample.boundsOf(used);
    if (bounds != null) {
      final double margin = spec.frameMargin;
      if (bounds.minX < margin ||
          bounds.minY < margin ||
          bounds.maxX > 1 - margin ||
          bounds.maxY > 1 - margin) {
        issues.add(ReadinessIssue.outOfFrame);
      }
    }

    final double? torso = FcGeometry.bodyScale(sample.metricSpace,
        minVisibility: spec.minVisibility);
    if (torso != null) {
      if (torso < spec.minTorsoFraction) {
        issues.add(ReadinessIssue.tooFar);
      } else if (torso > spec.maxTorsoFraction) {
        issues.add(ReadinessIssue.tooClose);
      }
    }

    final double? spread = FcGeometry.shoulderSpreadRatio(sample.metricSpace,
        minVisibility: spec.minVisibility);
    PreferredView detected = PreferredView.any;
    if (spread == null &&
        spec.requireConfirmedView &&
        spec.view != PreferredView.any) {
      issues.add(spec.view == PreferredView.side
          ? ReadinessIssue.wrongViewSide
          : ReadinessIssue.wrongViewFront);
    }
    if (spread != null) {
      if (spread >= FcTuning.frontViewMinSpread) {
        detected = PreferredView.front;
      } else if (spread <= FcTuning.sideViewMaxSpread) {
        detected = PreferredView.side;
      }
      if (spec.view == PreferredView.side &&
          spread > FcTuning.sideViewMaxSpread) {
        issues.add(ReadinessIssue.wrongViewSide);
      } else if (spec.view == PreferredView.front &&
          spread < FcTuning.frontViewMinSpread) {
        issues.add(ReadinessIssue.wrongViewFront);
      }
    }

    final double meanVisibility =
        used.isEmpty ? 0 : _meanVisibility(sample, used);
    if (used.isNotEmpty && meanVisibility < spec.minVisibility) {
      issues.add(ReadinessIssue.lowConfidence);
    }

    if (spec.checkLighting &&
        luma != null &&
        luma < FcTuning.lowLightMeanLuma) {
      issues.add(ReadinessIssue.lowLight);
    }
    if (subjectUnstable) issues.add(ReadinessIssue.cameraMoving);
    if (fps > 0 && fps < FcTuning.minUsableFps)
      issues.add(ReadinessIssue.lowFps);

    double progress = 0;
    bool ok = false;
    if (issues.isEmpty) {
      _okSinceMs ??= tMs;
      final int held = tMs - _okSinceMs!;
      progress =
          spec.stableMs <= 0 ? 1 : (held / spec.stableMs).clamp(0.0, 1.0);
      ok = held >= spec.stableMs;
    } else {
      _okSinceMs = null;
    }

    return _last = ReadinessReport(
      ok: ok,
      issues: issues,
      progress: progress,
      torsoFraction: torso,
      spreadRatio: spread,
      meanVisibility: meanVisibility,
      detectedView: detected,
      unknown: false,
    );
  }

  static double _meanVisibility(PoseSample sample, List<FcLandmark> landmarks) {
    double sum = 0;
    int count = 0;
    for (final FcLandmark landmark in landmarks) {
      final FcPoint? point = sample.points[landmark];
      if (point == null) continue;
      sum += point.visibility;
      count++;
    }
    if (count == 0) return 0;
    return sum / count;
  }

  void reset() {
    _okSinceMs = null;
    _last = ReadinessReport.unknownReport;
  }
}
