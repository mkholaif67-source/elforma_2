// Form Coach - camera lifecycle + frame pacing.
//
// Performance decisions made here:
//  - ResolutionPreset.high for preview, analysis and recording
//  - enableAudio: false (we never record audio)
//  - exactly ONE frame in flight; every frame that arrives while busy is dropped
//    and counted. This is what prevents inference backlog and thermal runaway.
//  - adaptive pacing: if inference gets slow on a weak device we increase the
//    frame interval instead of queueing work, so the preview stays smooth
//  - analysis frames are thrown away immediately; only an explicitly armed
//    local recorder may write an encoded video file to the phone.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:elforma/features/form_coach/runtime/camera_image_conversion.dart';
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

class _PreparedFrame {
  const _PreparedFrame({
    required this.input,
    required this.tMs,
    required this.width,
    required this.height,
    required this.luma,
  });

  final InputImage input;
  final int tMs;
  final double width;
  final double height;
  final double luma;
}

class CameraPosePipeline {
  CameraPosePipeline({required PoseDetectionService detector,
    Future<List<CameraDescription>> Function()? cameras,
    CameraController Function(CameraDescription)? cameraFactory})
      : _detector = detector, _camerasProvider = cameras ?? availableCameras,
        _cameraFactory = cameraFactory;
  final Future<List<CameraDescription>> Function() _camerasProvider;
  final CameraController Function(CameraDescription)? _cameraFactory;

  final PoseDetectionService _detector;
  final StreamController<PoseFrame> _frames = StreamController<PoseFrame>.broadcast();
  final Stopwatch _clock = Stopwatch();

  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  CameraLensDirection _lensDirection = CameraLensDirection.back;
  bool _streaming = false;
  bool _disposed = false;
  bool _inFlight = false;
  int _lastAcceptedMs = -1000;
  int _minIntervalMs = FcTuning.minFrameIntervalMs;
  int _dropped = 0;
  double _fps = 0;
  double _inferenceMs = 0;
  int? _lastProcessedMs;
  int _streamGeneration = 0;
  bool _recordingQuality = false;
  Future<void>? _analysis;
  Timer? _staleTimer;
  int _lastResultMs = 0;
  int _lastEmittedMs = -1;
  Future<void>? _startFuture;
  int _failedFrames = 0;
  int? _inFlightSinceMs;

  Stream<PoseFrame> get frames => _frames.stream;
  CameraController? get controller => _controller;
  bool get isStreaming => _streaming;
  bool get canSwitchCamera => _cameras.any((CameraDescription camera) =>
      camera.lensDirection != _lensDirection);
  int get droppedFrames => _dropped;
  double get fps => _fps;
  double get inferenceMs => _inferenceMs;
  int get frameIntervalMs => _minIntervalMs;
  bool get recordingQuality => _recordingQuality;

  bool get isMirrored =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  Future<void> start() {
    if (_disposed) return Future<void>.value();
    final existing = _startFuture;
    if (existing != null) return existing;
    final future = _startCamera();
    _startFuture = future;
    return future.whenComplete(() { if (identical(_startFuture, future)) _startFuture = null; });
  }
  Future<void> _startCamera() async {
    if (_disposed) return;
    if (_controller != null) { await resume(); return; }
    List<CameraDescription> cameras;
    try {
      cameras = await _camerasProvider().timeout(const Duration(seconds: 15));
    } on CameraException catch (error) {
      throw _mapException(error);
    }
    if (_disposed) return;
    if (cameras.isEmpty) {
      throw const FormCoachCameraException(
        CameraFailure.noCamera,
        'مفيش كاميرا متاحة على الجهاز',
      );
    }
    _cameras = cameras;

    final CameraDescription description = cameras.firstWhere(
      (CameraDescription camera) => camera.lensDirection == _lensDirection,
      orElse: () => cameras.first,
    );

    final CameraController controller = _cameraFactory?.call(description) ?? CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (_disposed) { await controller.dispose(); return; }
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (error) {
      await controller.dispose();
      if (error is CameraException) throw _mapException(error);
      rethrow;
    }

    if (_disposed) {
      await controller.dispose();
      return;
    }

    _controller = controller;
    if (!_clock.isRunning) _clock.start();
    _lensDirection = description.lensDirection;
    _lastResultMs = _clock.elapsedMilliseconds;
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_streaming && !_disposed && _inFlightSinceMs != null &&
          _clock.elapsedMilliseconds - _inFlightSinceMs! > 10000) {
        _failStream(); return;
      }
      if (_streaming && !_disposed && _clock.elapsedMilliseconds - _lastResultMs > 500) {
        _emitEmpty(_clock.elapsedMilliseconds);
      }
    });
    await resume();
  }

  Future<void> switchCamera() async {
    if (_disposed || !canSwitchCamera) return;
    final CameraLensDirection target =
        _lensDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;
    CameraDescription? description;
    for (final CameraDescription candidate in _cameras) {
      if (candidate.lensDirection == target) {
        description = candidate;
        break;
      }
    }
    if (description == null) return;
    final bool resumeAfter = _streaming;
    await pause();
    final CameraController? previous = _controller;
    _controller = null;
    await previous?.dispose();
    if (_disposed) return;
    await _detector.resetTracking();
    if (_disposed) return;
    final CameraController next = _cameraFactory?.call(description) ?? CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    try {
      await next.initialize().timeout(const Duration(seconds: 15));
      if (_disposed) { await next.dispose(); return; }
      await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (error) {
      await next.dispose();
      if (error is CameraException) throw _mapException(error);
      rethrow;
    }
    if (_disposed) {
      await next.dispose();
      return;
    }
    _lensDirection = target;
    _controller = next;
    if (resumeAfter) await resume();
  }

  /// Recording uses the same capture geometry as live analysis.
  Future<void> setRecordingQuality(bool enabled) async {
    // Keep analysis and preview at the same resolution while recording. Opening
    // at max caused expensive inference and changed crop mid-set on Android.
    _recordingQuality = enabled;
  }

  Future<void Function(CameraImage)> prepareRecording() async {
    await pause();
    final controller = _controller!;
    final generation = ++_streamGeneration;
    _streaming = true;
    return (image) {
      if (generation == _streamGeneration && identical(controller, _controller)) _onFrame(image);
    };
  }

  Future<void> resume() async {
    final CameraController? controller = _controller;
    if (controller == null || _disposed || _streaming) return;
    if (!controller.value.isInitialized) return;
    final generation = ++_streamGeneration;
    try {
      _streaming = true;
      _lastResultMs = _clock.elapsedMilliseconds;
      _failedFrames = 0;
      await controller.startImageStream((image) {
        if (generation == _streamGeneration && identical(controller, _controller)) _onFrame(image);
      });
    } on CameraException catch (error) {
      _streaming = false;
      throw _mapException(error);
    }
  }

  /// Immediately reject callbacks before awaiting any lifecycle cleanup.
  void stopAcceptingFrames() { _streaming = false; _streamGeneration++; }

  Future<void> suspend() async {
    stopAcceptingFrames();
    _staleTimer?.cancel(); _staleTimer = null;
    // Release capture before draining native inference: a slow detector must
    // not keep the camera open while the app is in the background.
    await _releaseCamera();
    await _analysis;
    if (!_disposed) await _detector.resetTracking();
  }

  Future<void> _releaseCamera() async {
    final camera = _controller;
    _controller = null;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages && !camera.value.isRecordingVideo) {
        await camera.stopImageStream();
      }
    } on CameraException catch (_) {
      // The platform may already have interrupted capture.
    } finally {
      await camera.dispose();
    }
  }

  Future<void> pause() async {
    final CameraController? controller = _controller;
    stopAcceptingFrames();
    try {
      if (controller != null && controller.value.isStreamingImages && !controller.value.isRecordingVideo) {
        await controller.stopImageStream();
      }
    } on CameraException catch (_) {
      // Already stopped by the platform (call, background): nothing to do.
    }
    await _analysis;
    _lastAcceptedMs = -1000;
    _lastProcessedMs = null;
    _fps = 0;
  }

  void _onFrame(CameraImage image) {
    if (_disposed || !_streaming) return;
    final int now = _clock.elapsedMilliseconds;
    final CameraController? controller = _controller;
    if (controller == null) return;

    // Pace before preparing buffers; never queue images behind inference.
    if (now - _lastAcceptedMs < _minIntervalMs) {
      _dropped++;
      return;
    }

    // Drop busy frames. The next camera callback supplies fresh motion.
    if (_inFlight || _detector.isBusy) {
      _dropped++;
      return;
    }


    final _PreparedFrame? prepared = _prepareFrame(
      image,
      controller.description,
      now,
      copyBytes: false,
    );
    if (prepared == null) {
      _dropped++;
      if (++_failedFrames >= 3) _failStream();
      return;
    }

    _inFlight = true;
    _inFlightSinceMs = now;
    _lastAcceptedMs = now;
    _analysis = _analyse(prepared, _streamGeneration);
  }

  _PreparedFrame? _prepareFrame(
    CameraImage image,
    CameraDescription description,
    int tMs, {
    required bool copyBytes,
  }) {
    final InputImage? input = _toInputImage(
      image,
      description,
      copyBytes: copyBytes,
    );
    if (input == null) return null;
    final int rotationRaw = Platform.isAndroid ? _rotation(description) : 0;
    final bool swap = rotationRaw == 90 || rotationRaw == 270;
    final double width = (swap ? image.height : image.width).toDouble();
    final double height = (swap ? image.width : image.height).toDouble();
    return _PreparedFrame(
      input: input,
      tMs: tMs,
      width: width,
      height: height,
      luma: _meanLuma(image),
    );
  }

  Future<void> _analyse(_PreparedFrame frame, int generation) async {
    final Stopwatch watch = Stopwatch()..start();
    try {
      final PoseSample? sample = await _detector.detect(
        image: frame.input,
        timestampMs: frame.tMs,
        rotatedWidth: frame.width,
        rotatedHeight: frame.height,
      );
      watch.stop();
      _failedFrames = 0;
      _inferenceMs = watch.elapsedMilliseconds.toDouble();
      _adaptPacing(_inferenceMs);

      final int? previous = _lastProcessedMs;
      if (previous != null && frame.tMs > previous) {
        final double instant = 1000 / (frame.tMs - previous);
        _fps = _fps == 0 ? instant : (_fps * 0.7 + instant * 0.3);
      }
      _lastProcessedMs = frame.tMs;

      // A result from a previous stream must never land after pause/resume or
      // set completion. This is the stale-result guard for the UI as well as
      // for the engine.
      if (_disposed || _frames.isClosed || !_streaming || generation != _streamGeneration) {
        return;
      }
      if (_clock.elapsedMilliseconds - frame.tMs > 500) {
        _emitEmpty(_clock.elapsedMilliseconds);
        return;
      }
      // A watchdog empty must never be followed by an older captured result.
      if (frame.tMs <= _lastEmittedMs) return;
      _lastEmittedMs = frame.tMs;
      _lastResultMs = _clock.elapsedMilliseconds;
      _frames.add(PoseFrame(
        tMs: frame.tMs,
        pose: sample,
        luma: frame.luma,
        inferenceMs: _inferenceMs,
        fps: _fps,
        droppedFrames: _dropped,
      ));
    } catch (_) {
      // A single failed frame must never kill the session.
      _dropped++;
      if (!_disposed && _streaming && generation == _streamGeneration) {
        _emitEmpty(_clock.elapsedMilliseconds);
        if (++_failedFrames >= 3) _failStream();
      }
    } finally {
      _inFlight = false;
      _inFlightSinceMs = null;
    }
  }

  void _failStream() {
    stopAcceptingFrames();
    if (!_disposed && !_frames.isClosed) {
      _frames.addError(const FormCoachCameraException(CameraFailure.unavailable,
        'التتبع وقف — جرّب فتح الكاميرا تاني'));
    }
  }

  void _emitEmpty(int tMs) {
    if (_frames.isClosed || tMs <= _lastEmittedMs) return;
    _lastEmittedMs = tMs;
    _lastResultMs = tMs;
    _frames.add(PoseFrame(tMs:tMs,pose:PoseSample.empty(tMs),luma:null,
      inferenceMs:_inferenceMs,fps:0,droppedFrames:_dropped));
  }

  /// Slow device: analyse less often instead of piling work up.
  void _adaptPacing(double inferenceMs) {
    if (inferenceMs > FcTuning.slowInferenceMs) {
      _minIntervalMs = math.min(FcTuning.maxFrameIntervalMs, _minIntervalMs + 15);
    } else if (_minIntervalMs > FcTuning.minFrameIntervalMs) {
      _minIntervalMs = math.max(FcTuning.minFrameIntervalMs, _minIntervalMs - 5);
    }
  }

  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription description, {
    required bool copyBytes,
  }) {
    final InputImageRotation rotation = Platform.isAndroid
        ? (InputImageRotationValue.fromRawValue(_rotation(description)) ??
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
    if (Platform.isAndroid && image.planes.length == 3) {
      bytes = packNv21(width: image.width, height: image.height,
        planes: image.planes.map((p) => p.bytes).toList(),
        rowStrides: image.planes.map((p) => p.bytesPerRow).toList(),
        pixelStrides: image.planes.map((p) => p.bytesPerPixel ?? 1).toList());
    } else if (image.planes.length != 1) {
      return null;
    } else if (Platform.isAndroid && bytes.length != image.width * image.height * 3 ~/ 2) {
      return null;
    }
    // A pending frame can outlive the camera callback, so it owns its bytes.
    // The immediately processed frame keeps the zero-copy fast path.
    if (copyBytes) bytes = Uint8List.fromList(bytes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: resolved,
        bytesPerRow: Platform.isAndroid ? image.width : plane.bytesPerRow,
      ),
    );
  }

  int _rotation(CameraDescription description) {
    const degrees = {DeviceOrientation.portraitUp: 0, DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180, DeviceOrientation.landscapeRight: 270};
    final value = _controller?.value;
    final orientation = value?.lockedCaptureOrientation ?? value?.deviceOrientation;
    return compensatedRotation(description.sensorOrientation, degrees[orientation] ?? 0,
        description.lensDirection == CameraLensDirection.front);
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
      'تعذر تشغيل الكاميرا. اقفلها وافتحها تاني',
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    stopAcceptingFrames();
    _staleTimer?.cancel();
    await _releaseCamera();
    await _analysis;
    await _detector.dispose();
    await _frames.close();
    _clock.stop();
  }
}
