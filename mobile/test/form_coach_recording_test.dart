import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elforma/features/form_coach/runtime/set_clip_recorder.dart';
import 'package:elforma/features/form_coach/runtime/local_video_saver.dart';
import 'package:elforma/features/form_coach/runtime/serial_operations.dart';

class FakeCamera extends CameraController {
  FakeCamera()
      : super(
            const CameraDescription(
                name: 'test',
                lensDirection: CameraLensDirection.back,
                sensorOrientation: 90),
            ResolutionPreset.high) {
    value = value.copyWith(isInitialized: true);
  }
  int starts = 0, stops = 0;
  Completer<void>? starting;
  @override
  Future<void> startVideoRecording(
      {void Function(CameraImage)? onAvailable,
      bool enablePersistentRecording = true}) async {
    starts++;
    await starting?.future;
    value = value.copyWith(isRecordingVideo: true);
  }

  @override
  Future<XFile> stopVideoRecording() async {
    stops++;
    value = value.copyWith(isRecordingVideo: false);
    return XFile('nonexistent-test-video.mp4');
  }
}

class Saver extends LocalVideoSaver {
  @override
  Future<String?> save(String path, {required String displayName}) async =>
      'content://saved';
}

class Recorder extends LocalSetClipRecorder {
  Recorder() : super(saver: Saver());
  @override
  bool get isAvailable => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('double start while native start is pending issues one native call',
      () async {
    final camera = FakeCamera()..starting = Completer<void>();
    final recorder = Recorder();
    final a = recorder.start(camera), b = recorder.start(camera);
    await Future<void>.delayed(Duration.zero);
    expect(camera.starts, 1);
    camera.starting!.complete();
    await Future.wait([a, b]);
    expect(recorder.isRecording, true);
    expect(camera.starts, 1);
    expect(await recorder.stop(camera), 'content://saved');
    expect(await recorder.stop(camera), isNull);
    expect(camera.stops, 1);
    await recorder.dispose();
  });
  test('dispose during pending start stops that camera exactly once', () async {
    final camera = FakeCamera()..starting = Completer<void>();
    final recorder = Recorder();
    final start = recorder.start(camera);
    await Future<void>.delayed(Duration.zero);
    final dispose = recorder.dispose();
    camera.starting!.complete();
    await Future.wait([start, dispose]);
    expect(camera.stops, 1);
    expect(recorder.isRecording, false);
    await recorder.start(camera);
    expect(camera.starts, 1);
  });
  test(
      'discard, start on new camera, then set completion leaves no stale owner',
      () async {
    final first = FakeCamera(), second = FakeCamera(), recorder = Recorder();
    await recorder.start(first);
    await recorder.discard();
    await recorder.start(second);
    await recorder.stop(second);
    expect(first.stops, 1);
    expect(second.stops, 1);
    expect(recorder.isRecording, false);
  });
  test(
      'serialized lifecycle resumes after pause finishes and recovers after failure',
      () async {
    final queue = SerialOperations(), pause = Completer<void>();
    final events = <String>[];
    final first = queue.run(() async {
      events.add('pause');
      await pause.future;
      events.add('paused');
    });
    final next = queue.run(() async {
      events.add('resume');
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, ['pause']);
    pause.complete();
    await Future.wait([first, next]);
    expect(events, ['pause', 'paused', 'resume']);
    await expectLater(
        queue.run(() async => throw StateError('failure')), throwsStateError);
    await queue.run(() async => events.add('recovered'));
    expect(events.last, 'recovered');
    expect(queue.busy, false,
        reason: 'Controls unlock before completion listeners run');
  });
}
