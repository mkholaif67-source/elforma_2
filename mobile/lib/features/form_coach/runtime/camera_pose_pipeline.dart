// Form Coach - camera lifecycle + frame pacing.
//
// Performance decisions made here:
//  - ResolutionPreset.medium: enough for pose, much cheaper than high/max
//  - enableAudio: false (we never record audio)
//  - exactly ONE frame in flight; every frame that arrives while busy is dropped
//    and counted. This is what prevents inference backlog and thermal runaway.
//  - adaptive pacing: if inference gets slow on a weak device we increase the
//    frame interval instead of queueing work, so the preview stays smooth
//  - frames are analysed and thrown away immediately; no bytes are stored,
//    copied to disk, or sent anywhere.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/domain/fc_tuning.dart';
import 'package:elforma/features/form_coach/runtime/pose_detection_service.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

enum CameraFailure { permissionDenied, noCamera, unavailable }

class FormCoachCameraException implements Exception {
  const FormCoachCameraException(this.failure, this.messageAr);

  final CameraFailure failure;
  final String messageAr;

  @override
  String toString() => 'FormCoachCameraException($failure): $messageAr';
}

/// One analysed frame. `pose` is empty when no person was found.
class PoseFrame {
  const PoseFrame({
    required this.tMs,
    required this.pose,
    required this.luma,
    required this.inferenceMs,
    required this.fps,
    required this.droppedFrames,
  });

  final int tMs;
  final PoseSample? pose;
  final double? luma;
  final double inferenceMs;
  final double fps;
  final int droppedFrames;
}

class CameraPosePipeline {
  CameraPosePipeline({required PoseDetectionService detector})
      : _detector = detector;

  final PoseDetectionService _detector;
  final StreamController<PoseFrame> _frames = StreamController<PoseFrame>.broadcast();
  final Stopwatch _clock = Stopwatch();

  CameraController? _controller;
  bool _streaming = false;
  bool _disposed = false;
  bool _inFlight = false;
  int _lastAcceptedMs = -1000;
  int _minIntervalMs = FcTuning.minFrameIntervalMs;
  int _dropped = 0;
  double _fps = 0;
  double _inferenceMs = 0;
  int? _lastProcessedMs;

  Stream<PoseFrame> get frames => _frames.stream;
  CameraController? get controller => _controller;
  bool get isStreaming => _streaming;
  int get droppedFrames => _dropped;
  double get fps => _fps;
  double get inferenceMs => _inferenceMs;
  int get frameIntervalMs => _minIntervalMs;

  bool get isMirrored =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  Future<void> start() async {
    if (_disposed) return;
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (error) {
      throw _mapException(error);
    }
    if (cameras.isEmpty) {
      throw const FormCoachCameraException(
        CameraFailure.noCamera,
        'مفيش كاميرا متاحة على الجهاز',
      );
    }

    final CameraDescription description = cameras.firstWhere(
      (CameraDescription camera) =>
          camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final CameraController controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
    } on CameraException catch (error) {
      await controller.dispose();
      throw _mapException(error);
    }

    if (_disposed) {
      await controller.dispose();
      return;
    }

    _controller = controller;
    _clock
      ..reset()
      ..start();
    await resume();
  }

  Future<void> resume() async {
    final CameraController? controller = _controller;
    if (controller == null || _disposed || _streaming) return;
    if (!controller.value.isInitialized) return;
    try {
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } on CameraException catch (error) {
      throw _mapException(error);
    }
  }

  Future<void> pause() async {
    final CameraController? controller = _controller;
    if (controller == null || !_streaming) return;
    _streaming = false;
    try {
      await controller.stopImageStream();
    } on CameraException catch (_) {
      // Already stopped by the platform (call, background): nothing to do.
    }
  }

  void _onFrame(CameraImage image) {
    if (_disposed || !_streaming) return;
    final int now = _clock.elapsedMilliseconds;

    // Backpressure: drop instead of queueing.
    if (_inFlight || _detector.isBusy || now - _lastAcceptedMs < _minIntervalMs) {
      _dropped++;
      return;
    }

    final CameraController? controller = _controller;
    if (controller == null) return;

    final InputImage? input = _toInputImage(image, controller.description);
    if (input == null) {
      _dropped++;
      return;
    }

    _inFlight = true;
    _lastAcceptedMs = now;
    final int rotationRaw = Platform.isAndroid
        ? controller.description.sensorOrientation
        : 0;
    final bool swap = rotationRaw == 90 || rotationRaw == 270;
    final double width = (swap ? image.height : image.width).toDouble();
    final double height = (swap ? image.width : image.height).toDouble();
    final double luma = _meanLuma(image);

    _analyse(input, now, width, height, luma);
  }

  Future<void> _analyse(
    InputImage input,
    int tMs,
    double width,
    double height,
    double luma,
  ) async {
    final Stopwatch watch = Stopwatch()..start();
    try {
      final PoseSample? sample = await _detector.detect(
        image: input,
        timestampMs: tMs,
        rotatedWidth: width,
        rotatedHeight: height,
      );
      watch.stop();
      _inferenceMs = watch.elapsedMilliseconds.toDouble();
      _adaptPacing(_inferenceMs);

      final int? previous = _lastProcessedMs;
      if (previous != null && tMs > previous) {
        final double instant = 1000 / (tMs - previous);
        _fps = _fps == 0 ? instant : (_fps * 0.7 + instant * 0.3);
      }
      _lastProcessedMs = tMs;

      if (_disposed || _frames.isClosed) return;
      _frames.add(PoseFrame(
        tMs: tMs,
        pose: sample,
        luma: luma,
        inferenceMs: _inferenceMs,
        fps: _fps,
        droppedFrames: _dropped,
      ));
    } catch (_) {
      // A single failed frame must never kill the session.
      _dropped++;
    } finally {
      _inFlight = false;
    }
  }

  /// Slow device: analyse less often instead of piling work up.
  void _adaptPacing(double inferenceMs) {
    if (inferenceMs > FcTuning.slowInferenceMs) {
      _minIntervalMs = math.min(FcTuning.maxFrameIntervalMs, _minIntervalMs + 15);
    } else if (_minIntervalMs > FcTuning.minFrameIntervalMs) {
      _minIntervalMs = math.max(FcTuning.minFrameIntervalMs, _minIntervalMs - 5);
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription description) {
    final InputImageRotation rotation = Platform.isAndroid
        ? (InputImageRotationValue.fromRawValue(description.sensorOrientation) ??
            InputImageRotation.rotation0deg)
        : InputImageRotation.rotation0deg;

    final InputImageFormat? format =
        InputImageFormatValue.fromRawValue(image.format.raw is int ? image.format.raw as int : 0);

    if (image.planes.isEmpty) return null;
    final Plane plane = image.planes.first;

    // Android: nv21 (single interleaved buffer). iOS: bgra8888 (single plane).
    final InputImageFormat resolved = Platform.isAndroid
        ? InputImageFormat.nv21
        : (format ?? InputImageFormat.bgra8888);

    Uint8List bytes = plane.bytes;
    if (Platform.isAndroid && image.planes.length > 1) {
      final BytesBuilder builder = BytesBuilder(copy: false);
      for (final Plane part in image.planes) {
        builder.add(part.bytes);
      }
      bytes = builder.toBytes();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: resolved,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Cheap brightness estimate from the luma plane (sparse sampling) so the
  /// ready check can warn about bad lighting instead of blaming the user.
  double _meanLuma(CameraImage image) {
    if (image.planes.isEmpty) return 255;
    final Uint8List bytes = image.planes.first.bytes;
    if (bytes.isEmpty) return 255;
    final int step = Platform.isAndroid ? 97 : 397;
    int sum = 0;
    int count = 0;
    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
      count++;
    }
    if (count == 0) return 255;
    return sum / count;
  }

  FormCoachCameraException _mapException(CameraException error) {
    final String code = error.code.toLowerCase();
    if (code.contains('permission') || code.contains('denied')) {
      return const FormCoachCameraException(
        CameraFailure.permissionDenied,
        'محتاجين إزن الكاميرا علشان تابع أداءك يشتغل',
      );
    }
    return FormCoachCameraException(
      CameraFailure.unavailable,
      'مش قادر أفتح الكاميرا (${error.code})',
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await pause();
    final CameraController? controller = _controller;
    _controller = null;
    await controller?.dispose();
    await _detector.dispose();
    await _frames.close();
    _clock.stop();
  }
}
