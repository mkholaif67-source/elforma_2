'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

const recorder = read('mobile/lib/features/form_coach/runtime/set_clip_recorder.dart');
const saver = read('mobile/lib/features/form_coach/runtime/local_video_saver.dart');
const pipeline = read('mobile/lib/features/form_coach/runtime/camera_pose_pipeline.dart');
const controller = read('mobile/lib/features/form_coach/runtime/form_coach_controller.dart');
const android = read('mobile/android/app/src/main/kotlin/com/elforma/elforma/MainActivity.kt');
const manifest = read('mobile/android/app/src/main/AndroidManifest.xml');
const screen = read('mobile/lib/features/form_coach/ui/form_coach_screen.dart');

assert(recorder.includes('class LocalSetClipRecorder'));
assert(recorder.includes('startVideoRecording'));
assert(recorder.includes('stopVideoRecording'));
assert(recorder.includes('LocalVideoSaver'));
assert(recorder.includes('Platform.isAndroid'));
assert(saver.includes("MethodChannel('elforma/local_video')"));
assert(saver.includes("requestWritePermission"));
assert(!pipeline.includes('ResolutionPreset.max'));
assert(pipeline.includes('ResolutionPreset.high'));
assert(recorder.includes('enablePersistentRecording: false'));
assert(recorder.includes('onAvailable: onAvailable'));
assert(recorder.includes('SerialOperations'));
assert(pipeline.includes('setRecordingQuality'));
assert(controller.includes('recorder ?? LocalSetClipRecorder()'));
assert(controller.includes('_finishRecordingAndPause'));
assert(controller.includes('_recorder.stop(camera)'));
assert(android.includes('MediaStore.Video.Media.RELATIVE_PATH'));
assert(android.includes('ElForma/Form Coach'));
assert(android.includes('IS_PENDING'));
assert(android.includes('input.copyTo(output)'));
const localSaveSection = android.slice(android.indexOf('private fun saveVideoToDevice'));
assert(!localSaveSection.includes('http://') && !localSaveSection.includes('https://'));
assert(manifest.includes('WRITE_EXTERNAL_STORAGE'));
assert(screen.includes('تسجيل المجموعة وحفظها على الموبايل'));

console.log('Form Coach local-recording contract: all assertions passed');
