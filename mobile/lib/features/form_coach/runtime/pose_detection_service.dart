// Form Coach - pose detection (Google ML Kit Pose Detection, on-device).
//
// Why ML Kit:
//  - runs fully on-device and offline, no frame ever leaves the phone
//  - stable, maintained Flutter plugin with Android + iOS support
//  - stream mode is tuned for live camera use (tracking between frames)
//  - the model ships inside the app, so first use needs no download
//
// This class is the only place that knows about ML Kit types. Everything above
// it works with our own PoseSample, so the detector can be replaced later
// without touching the engine, the profiles or the UI.

import 'dart:math' as math;

import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectionService {
  PoseDetectionService({PoseDetectionModel model = PoseDetectionModel.base})
      : _detector = PoseDetector(
          options: PoseDetectorOptions(
            model: model,
            // Stream mode: lower latency and landmark tracking across frames.
            mode: PoseDetectionMode.stream,
          ),
        );

  PoseDetector _detector;
  bool _busy = false;
  bool _closed = false;

  /// True while a frame is being analysed. The pipeline uses this to make sure
  /// only one frame is ever in flight (no inference backlog).
  bool get isBusy => _busy;

  static const Map<PoseLandmarkType, FcLandmark> _mapping =
      <PoseLandmarkType, FcLandmark>{
    PoseLandmarkType.nose: FcLandmark.nose,
    PoseLandmarkType.leftEar: FcLandmark.leftEar,
    PoseLandmarkType.rightEar: FcLandmark.rightEar,
    PoseLandmarkType.leftShoulder: FcLandmark.leftShoulder,
    PoseLandmarkType.rightShoulder: FcLandmark.rightShoulder,
    PoseLandmarkType.leftElbow: FcLandmark.leftElbow,
    PoseLandmarkType.rightElbow: FcLandmark.rightElbow,
    PoseLandmarkType.leftWrist: FcLandmark.leftWrist,
    PoseLandmarkType.rightWrist: FcLandmark.rightWrist,
    PoseLandmarkType.leftHip: FcLandmark.leftHip,
    PoseLandmarkType.rightHip: FcLandmark.rightHip,
    PoseLandmarkType.leftKnee: FcLandmark.leftKnee,
    PoseLandmarkType.rightKnee: FcLandmark.rightKnee,
    PoseLandmarkType.leftAnkle: FcLandmark.leftAnkle,
    PoseLandmarkType.rightAnkle: FcLandmark.rightAnkle,
    PoseLandmarkType.leftHeel: FcLandmark.leftHeel,
    PoseLandmarkType.rightHeel: FcLandmark.rightHeel,
    PoseLandmarkType.leftFootIndex: FcLandmark.leftFootIndex,
    PoseLandmarkType.rightFootIndex: FcLandmark.rightFootIndex,
  };

  /// Analyses one frame. Returns null when a frame is already in flight, and an
  /// empty sample when nobody is detected (which is different from "no data").
  Future<PoseSample?> detect({
    required InputImage image,
    required int timestampMs,
    required double rotatedWidth,
    required double rotatedHeight,
  }) async {
    if (_closed || _busy) return null;
    _busy = true;
    try {
      final List<Pose> poses = await _detector.processImage(image);
      if (poses.isEmpty) return PoseSample.empty(timestampMs);
      final Pose pose = _mainSubject(poses);
      return _toSample(pose, timestampMs, rotatedWidth, rotatedHeight);
    } finally {
      _busy = false;
    }
  }

  /// If several people are visible we keep the largest body (closest to the
  /// camera). Bystanders are further handled by SubjectTracker.
  Pose _mainSubject(List<Pose> poses) {
    if (poses.length == 1) return poses.first;
    Pose best = poses.first;
    double bestScore = -1;
    for (final Pose pose in poses) {
      double minY = double.infinity;
      double maxY = -double.infinity;
      double likelihood = 0;
      int count = 0;
      for (final PoseLandmark landmark in pose.landmarks.values) {
        minY = math.min(minY, landmark.y);
        maxY = math.max(maxY, landmark.y);
        likelihood += landmark.likelihood;
        count++;
      }
      if (count == 0) continue;
      final double score = (maxY - minY) * (likelihood / count);
      if (score > bestScore) {
        bestScore = score;
        best = pose;
      }
    }
    return best;
  }

  PoseSample _toSample(Pose pose, int timestampMs, double width, double height) {
    final Map<FcLandmark, FcPoint> points = <FcLandmark, FcPoint>{};
    final double safeWidth = width <= 0 ? 1 : width;
    final double safeHeight = height <= 0 ? 1 : height;

    for (final MapEntry<PoseLandmarkType, PoseLandmark> entry
        in pose.landmarks.entries) {
      final FcLandmark? target = _mapping[entry.key];
      if (target == null) continue;
      final PoseLandmark landmark = entry.value;
      points[target] = FcPoint(
        x: landmark.x / safeWidth,
        y: landmark.y / safeHeight,
        // z is a single-view estimate: overlay/debug only, never used by rules.
        z: landmark.z / safeWidth,
        visibility: landmark.likelihood.clamp(0.0, 1.0),
      );
    }

    return PoseSample(timestampMs: timestampMs, points: points, imageAspect: safeWidth / safeHeight);
  }

  Future<void> resetTracking() async {
    if (_closed) return;
    await _detector.close();
    _detector = PoseDetector(options: PoseDetectorOptions(
      model: PoseDetectionModel.base, mode: PoseDetectionMode.stream));
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _detector.close();
  }
}
