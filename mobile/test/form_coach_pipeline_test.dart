import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:elforma/features/form_coach/domain/fc_landmarks.dart';
import 'package:elforma/features/form_coach/runtime/camera_pose_pipeline.dart';
import 'package:elforma/features/form_coach/runtime/pose_detection_service.dart';

const cameras = [
  CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90),
  CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270)
];

class TestCamera extends CameraController {
  TestCamera(CameraDescription description)
      : super(description, ResolutionPreset.high);
  void Function(CameraImage)? callback;
  bool closed = false;
  @override
  Future<void> initialize() async {
    value = value.copyWith(isInitialized: true);
  }

  @override
  Future<void> lockCaptureOrientation([DeviceOrientation? orientation]) async {}
  @override
  Future<void> startImageStream(void Function(CameraImage) onAvailable) async {
    callback = onAvailable;
    value = value.copyWith(isStreamingImages: true);
  }

  @override
  Future<void> stopImageStream() async {
    value = value.copyWith(isStreamingImages: false);
  }

  @override
  Future<void> dispose() async {
    closed = true;
    await super.dispose();
  }
}

class Detector extends PoseDetectionService {
  Completer<PoseSample?>? pending;
  int calls = 0, resets = 0;
  @override
  Future<PoseSample?> detect(
      {required InputImage image,
      required int timestampMs,
      required double rotatedWidth,
      required double rotatedHeight}) {
    calls++;
    pending = Completer<PoseSample?>();
    return pending!.future;
  }

  @override
  Future<void> resetTracking() async {
    resets++;
  }

  @override
  Future<void> dispose() async {}
}

CameraImage frame() =>
    // Compatibility constructor permits a platform-independent synthetic buffer.
    // ignore: deprecated_member_use
    CameraImage.fromPlatformData({
      'format': 1111970369,
      'width': 4,
      'height': 4,
      'planes': [
        {'bytes': Uint8List(64), 'bytesPerRow': 16, 'bytesPerPixel': 4},
      ]
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('suspend releases capture before a delayed detector finishes', () async {
    final detector = Detector();
    late TestCamera camera;
    final pipeline = CameraPosePipeline(
      detector: detector,
      cameras: () async => cameras,
      cameraFactory: (description) => camera = TestCamera(description),
    );
    await pipeline.start();
    camera.callback!(frame());
    expect(detector.calls, 1);
    final suspending = pipeline.suspend();
    await Future<void>.delayed(Duration.zero);
    expect(camera.closed, isTrue);
    expect(pipeline.controller, isNull);
    expect(pipeline.isStreaming, isFalse);
    detector.pending!.complete(PoseSample.empty(1));
    await suspending;
    await pipeline.dispose();
  });

  test(
      'busy frames do not queue; old results and callbacks never cross a camera switch',
      () async {
    final detector = Detector(),
        made = <TestCamera>[],
        received = <PoseFrame>[];
    final pipeline = CameraPosePipeline(
        detector: detector,
        cameras: () async => cameras,
        cameraFactory: (description) {
          final camera = TestCamera(description);
          made.add(camera);
          return camera;
        });
    final subscription = pipeline.frames.listen(received.add);
    await pipeline.start();
    final old = made.single.callback!;
    old(frame());
    await Future<void>.delayed(const Duration(milliseconds: 80));
    old(frame());
    old(frame());
    expect(detector.calls, 1);
    final switchFuture = pipeline.switchCamera();
    await Future<void>.delayed(Duration.zero);
    expect(made.single.closed, false,
        reason: 'Drain inference before disposing its camera');
    detector.pending!.complete(PoseSample(timestampMs: 0, points: {
      FcLandmark.nose: const FcPoint(x: .2, y: .2, visibility: .9)
    }));
    await switchFuture;
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
    expect(detector.resets, 1);
    expect(made.first.closed, true);
    old(frame());
    expect(detector.calls, 1,
        reason: 'Old subscription is invalid even after resume');
    made.last.callback!(frame());
    expect(detector.calls, 2);
    detector.pending!.complete(PoseSample.empty(100));
    await Future<void>.delayed(Duration.zero);
    expect(received.length, 1);
    await pipeline.dispose();
    await subscription.cancel();
  });
  test('stalled stream clears pose and a late inference cannot restore it',
      () async {
    final detector = Detector(), received = <PoseFrame>[];
    late TestCamera camera;
    final pipeline = CameraPosePipeline(
        detector: detector,
        cameras: () async => cameras,
        cameraFactory: (description) => camera = TestCamera(description));
    final subscription = pipeline.frames.listen(received.add);
    await pipeline.start();
    camera.callback!(frame());
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(received, isNotEmpty);
    expect(received.every((frame) => frame.pose!.isEmpty), true);
    detector.pending!.complete(PoseSample(timestampMs: 0, points: {
      FcLandmark.nose: const FcPoint(x: .2, y: .2, visibility: .9)
    }));
    await Future<void>.delayed(Duration.zero);
    expect(received.every((frame) => frame.pose!.isEmpty), true);
    await pipeline.dispose();
    await subscription.cancel();
  });
  test(
      'failed inference clears the displayed pose rather than retaining a ghost',
      () async {
    final detector = Detector(), received = <PoseFrame>[];
    late TestCamera camera;
    final pipeline = CameraPosePipeline(
        detector: detector,
        cameras: () async => cameras,
        cameraFactory: (description) => camera = TestCamera(description));
    final subscription = pipeline.frames.listen(received.add);
    await pipeline.start();
    camera.callback!(frame());
    detector.pending!.completeError(StateError('bad frame'));
    await Future<void>.delayed(Duration.zero);
    expect(received.single.pose!.isEmpty, true);
    await pipeline.dispose();
    await subscription.cancel();
  });
  test('concurrent starts create exactly one camera controller', () async {
    final detector = Detector(), made = <TestCamera>[];
    final pipeline = CameraPosePipeline(detector: detector, cameras: () async => cameras,
      cameraFactory: (description) {
        final camera = TestCamera(description); made.add(camera); return camera;
      });
    await Future.wait([pipeline.start(), pipeline.start()]);
    expect(made.length, 1);
    expect(pipeline.isStreaming, true);
    await pipeline.dispose();
  });
  test('dispose during camera discovery never creates a late camera', () async {
    final discovered = Completer<List<CameraDescription>>();
    var created = 0;
    final pipeline = CameraPosePipeline(detector: Detector(), cameras: () => discovered.future,
      cameraFactory: (description) { created++; return TestCamera(description); });
    final starting = pipeline.start();
    await pipeline.dispose();
    discovered.complete(cameras);
    await starting;
    expect(created, 0);
    expect(pipeline.controller, isNull);
  });
  test('background suspend releases camera and invalidates its callbacks', () async {
    final detector = Detector(), made = <TestCamera>[];
    final pipeline = CameraPosePipeline(detector: detector, cameras: () async => cameras,
      cameraFactory: (description) {
        final camera = TestCamera(description); made.add(camera); return camera;
      });
    await pipeline.start();
    final old = made.single.callback!;
    pipeline.stopAcceptingFrames();
    old(frame());
    expect(detector.calls, 0);
    await pipeline.suspend();
    expect(made.single.closed, true);
    expect(pipeline.controller, isNull);
    await pipeline.start();
    expect(made.length, 2);
    old(frame());
    expect(detector.calls, 0);
    made.last.callback!(frame());
    expect(detector.calls, 1);
    detector.pending!.complete(PoseSample.empty(0));
    await Future<void>.delayed(Duration.zero);
    await pipeline.dispose();
  });

}
