# Form Coach stabilization — code handoff, Android validation pending

Source: user-uploaded elforma(2).zip (identical contents to elforma(1).zip).
Scope: existing Form Coach architecture only. No new dependencies or alternate engine. No changes to workout, nutrition, subscription, database contents, Android build configuration or CI workflow. This is not a certified production release: Flutter compilation/widget tests and physical Android acceptance are still outstanding.

## Pipeline inspected
CameraPosePipeline accepts a fresh callback only when pacing allows and no inference is in flight. Camera conversion supplies rotation-corrected input to PoseDetectionService (ML Kit stream mode). FormCoachEngine applies subject/quality/readiness checks, profile selection, independent analysis and visual smoothing, metric evaluation, active-side selection and RepCounter phase/ROM gates. Rule persistence and rep events feed assessment counters, audio and the immutable snapshot. Controller now sends pose snapshots independently to the overlay; ordinary text updates are paced separately. The verified-profile resolver remains authoritative; transient uncertainty never selects fallback.

## Reproduced causes and fixes
- A confidence gap could poison a cycle that then disappeared at return. Meaningful uncertain cycles now generate one Cannot Assess attempt, not a valid/incorrect/partial form judgment.
- Gaps between callbacks were checked after overwriting the last usable timestamp. Long gaps now interrupt continuity before accepting new movement. Duplicate/backward samples are ignored.
- Time spent waiting at the return endpoint could satisfy minimum duration for an implausibly fast impulse. Duration now ends at first return; persistence still confirms the endpoint. Existing thresholds/hysteresis are retained.
- Classification only saw a rule firing on the completion frame. Persistent evaluable errors now survive across the cycle independently of audio cooldown.
- View revalidation reset session totals. Totals now survive variant changes; restart explicitly resets them.
- Overlay filtering changed active-side state and could abort analysis. Analysis selects/locks the side; rendering has no such side effects.
- Global head visibility rejected an otherwise complete required upper-body chain. Required-joint/readiness checks remain authoritative with anatomy/confidence checks retained.
- Generic hinge and shoulder-elevation metrics could use the wrong joint. Hip hinge uses shoulder/hip/knee; elevation uses arm relative to torso. Synthetic geometry tests cover straight knee/elbow motion. This does NOT validate every catalog exercise clinically or biomechanically.

## Files and principal functions
- domain/rep_cycle.dart: update/interrupt/abortCycle/reset, return timing, gap events.
- domain/form_coach_engine.dart: onFrame, activation/revalidation, side selection, cycle classification, interruption/reset.
- domain/assessment.dart: explicit cannotAssessAttempts.
- domain/pose_quality_gate.dart: required-chain admission without mandatory head.
- profiles/catalog_form_profiles.dart and fallback_form_engine.dart: shared hinge/elevation drivers and active unilateral side.
- runtime/camera_pose_pipeline.dart: start, resume, suspend, pause, switchCamera, _analyse, _releaseCamera, dispose.
- runtime/form_coach_controller.dart: start/retry, _onFrame, pipeline errors, lifecycle/camera/session transitions and dispose.
- runtime/form_cue_player.dart: cancellation generations and nonoverlapping feedback.
- ui/form_coach_screen.dart: independent pose rendering, visible counters, retry, scroll-safe content, neutral tracking wording.
- ui/widgets/readiness_panel.dart: one normal-mode setup instruction.
- ui/widgets/cue_banner.dart: initial cue visibility and cancellable timer.
(All paths above are below mobile/lib/features/form_coach.)

## Performance, camera and UX
No pending image queue was added: busy camera callbacks are dropped and the next accepted callback is fresh. Duplicate startup is coalesced. Stale generations, late results and out-of-order watchdog results cannot enter the engine. Existing adaptive inference pacing and separate smoothers remain; no claim of measured latency or thermal improvement is made. Pose rendering uses a ValueNotifier and RepaintBoundary; ordinary screen notifications are limited to 5 Hz, while counter/safety changes remain immediate.

Audio setup no longer blocks camera startup. Discovery/initialization have deadlines and failures expose retry. Background/exit invalidates callbacks immediately; capture is released before waiting for in-flight inference to drain. Camera changes and resume require revalidation. Corrections are suppressed when assessment is uncertain; correct reps remain silent. Rep acknowledgement is lightweight and respects reduced motion. Text can scroll on small screens instead of overflowing.

## Validation actually executed
- Standalone Dart 3.10.8: 70 regression cases passed in mobile/tool/form_coach_regression.dart.
- Dart analyzer: domain, profiles and standalone harness — no issues.
- Dart parser/formatter dry run: modified runtime/UI/test files parse. This is NOT Flutter type checking.
- Node: all 86 test files passed. These include source contracts and server tests, not Android camera acceptance. The two affected Form Coach contract files were rerun successfully after the final camera/audio changes.
- Test execution touched the local database; its exact original ZIP bytes were restored before packaging. No database change is delivered.

Coverage includes normal/slow/fast cycles across 13 profile variants, partial ROM, interruption, confidence/callback gaps, threshold jitter, no movement/no double count, timestamp ordering, body proportions, actual synthetic pose-to-engine counters, persistent rule classification, variant/session/exercise transitions, cropped head and hinge/elevation geometry. Scalar-driver family replay cannot establish ML Kit accuracy across all named exercises.

Flutter tests added/updated (NOT executed here): form_coach_pipeline_test.dart, form_coach_rep_cycle_test.dart, form_coach_stabilization_test.dart. They cover single-flight/stale callbacks, camera startup deduplication, disposal during discovery, suspend/recreate, camera release during pending inference, initial cue and timer disposal, and run the 70-case domain harness through normal CI.

Flutter execution in this session was rejected by automatic approval review because the invocation attempted cloud-instance metadata access. That restriction was not bypassed. No APK was built here and no physical Android measurements were taken.

## Remaining acceptance gates / known limits
1. Run Flutter analyze/test and build in the project's existing GitHub workflow. Runtime/plugin types and widget behavior remain unverified here.
2. Test front/back cameras, mirroring/rotation, permission denial/revocation, repeated switch/retry, background/foreground/calls, exit/reentry, new session and exercise changes on Android.
3. Test small screens/large text and keyboard-free coach controls; verify no clipped text and readiness/correction stability during real motion.
4. Replay real normal/slow/fast/partial movement and temporary occlusion across movement families. Measure actual response delay, device load and temperature on low/mid/high-tier phones.
5. Catalog profiles remain heterogeneous: broad fly/calf/shrug/rear-delt mappings need exercise-specific biomechanical validation. No unsupported form rules were enabled. Tracking-only completed cycles must not be interpreted as proof of technically correct form. Confidence loss stays Cannot Assess, never fallback.
6. A native ML Kit call that never resolves cannot be cancelled safely by the current plugin abstraction. The watchdog reports a failure and capture is released, but detector draining can still block retry. Do not label this scenario resolved without native Android verification/cancellation support.
7. Cold model startup still occurs through the existing detector; no unverified warm-up workload was added.

## Conservative cleanup
Removed only mobile/.idea/workspace.xml, mobile/.idea/deviceManager.xml and mobile/.idea/caches/deviceStreaming.xml: local IDE session/device state, excluded by the existing mobile/.gitignore, with no project source/build references. Other IDE definitions, project history, assets, source and scripts are retained. The temporary .dart_tool/package_config.json used for standalone analysis is excluded from delivery. No files on the user's computer were accessed or deleted.
