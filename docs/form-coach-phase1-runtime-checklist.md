# Form Coach Phase 1 — Physical-device runtime checklist

This checklist is required after installing the Android build. It is intentionally separate from static and automated source checks.

## Test matrix

Use one low-end Android phone, one average phone, and one recent phone. Record model, Android version, camera lens, resolution preset reported by the plugin, ambient light, battery percentage, and whether recording is armed.

### Camera readiness

- [ ] Camera permission denied: the app shows the existing Arabic permission error and does not crash.
- [ ] Camera permission granted: preview opens and the readiness panel appears.
- [ ] Low light: the app reports low-light guidance instead of counting.
- [ ] Person too far / too close / outside frame: the app stays in `Cannot Assess` and does not create reps.
- [ ] Move the phone or change the camera view: the readiness state recovers without stale skeleton points.

### Rep counting

For each speed, perform three complete repetitions from a visible top position through full range and back:

- [ ] 3 slow repetitions: exactly 3 reps.
- [ ] 3 normal repetitions: exactly 3 reps.
- [ ] 3 fast but valid repetitions: exactly 3 reps; no delayed or missing commit.
- [ ] Partial range: 0 full reps for the partial movement; incomplete feedback is allowed.
- [ ] Reverse direction halfway through a rep: no false rep.
- [ ] Hold/jitter around a threshold: no double count.
- [ ] Stop in the middle of a rep: no rep is committed after the confidence gap.
- [ ] Hide the wrist/joint from the camera: the system returns to Cannot Assess and does not jump the counter.
- [ ] Restore the joint: tracking resumes without importing the old stale pose.

### Lifecycle and set boundaries

- [ ] Pause the app during an active rep, resume, and confirm no stale result appears.
- [ ] Switch front/back camera and confirm tracking restarts with the correct mirror state.
- [ ] Complete the target set and confirm the camera stream stops.
- [ ] Confirm the skeleton disappears on the finished screen.
- [ ] Start a new set and confirm the previous pose, in-flight rep, and counter do not carry over.
- [ ] Repeat a new set after a completed recorded set; confirm local video state does not affect rep state.

### Quality, performance, and heat

- [ ] Normal Form Coach preview is visibly clearer than the old medium-preset build.
- [ ] Preview aspect ratio is not stretched or digitally zoomed.
- [ ] Observe FPS, inference time, dropped frames, and device temperature at 5, 10, and 15 minutes.
- [ ] On a weak device, confirm analysis rate slows rather than the app freezing or accumulating lag.
- [ ] With recording off, confirm no video file is created and resource use remains stable.
- [ ] With recording on, confirm max quality is used only after arming and the set still completes.

## Acceptance evidence

Capture a screen recording or test notes for every failed case, including:

- device model and Android version;
- camera lens and orientation;
- approximate FPS, inference time, and dropped-frame count;
- start/end battery and temperature if available;
- whether the failure reproduced after a fresh app restart.

A passed static contract is not a substitute for this physical-device checklist.
