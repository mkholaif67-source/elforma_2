# Form Coach implementation report — 2026-09-23

**Overall status: Partially completed; automated gates pass, independent camera accuracy and physical-device acceptance remain pending.**

This delivery repairs shared counting, evidence, pacing and lifecycle behavior and expands movement-specific tracking beyond biceps. It does **not** establish a universally accurate form coach, eliminate measured phone heat, or deliver a trained exercise-recognition model. The existing architecture and original dependency lock are preserved. Earlier reports under PROJECT_AUDIT describe the supplied baseline; this report describes this delivery.

## Delivered scope

- Separate tracked repetitions from repetitions that actually passed supported form checks. A profile with no rules never certifies correct technique.
- Preserve a count across a brief occlusion only after the endpoint was observed, with bounded time and movement continuity. A missing endpoint, long gap, nonfinite value or repeated/reversed timestamp cannot earn a rep. Returning to the starting zone must independently persist before committing.
- Observe sustained rule violations independently of speech cooldown; only the cue selected by arbitration consumes its speech budget. Per-rep evidence records supported errors and requires two later observable clean reps before confirming improvement.
- Constrain session-local neutral calibration by posture, spread, sample count, camera view and side. This is calibration, not learning a correct movement from arbitrary initial repetitions.
- Match specific body chains before generic catalog aliases: fly/reverse fly, calf raise, leg curl, hip adduction, pullover, face pull and shrug. Keep all these new proxies tracking-only. Generic press, row, squat/lunge, raise, hinge and core tracking still share the repaired engine.
- Use the moving side for unilateral/catalog/fallback tracking, collecting motion evidence during a cycle while forbidding a side switch inside it. A stationary support arm no longer necessarily controls the driver.
- Permit genuinely visible hip–knee–ankle chains when shoulders are cropped on lower-body-only profiles. Keep upper-body requirements intact. An invisible heel no longer removes an independently visible toe.
- Provide prescribed-tempo feedback across profiles; no speed judgment without an explicit session prescription. Two later assessable repetitions verify timing improvement. Summary distinguishes this from anatomical correction.
- Apply bounded, recording-aware pacing with hysteresis and local conversion/inference p50/p95 metrics. Preserve one frame in flight, stale-result guards and the existing default resolution/FPS. Brightness sampling is bounded to 96 samples and excludes NV21 chroma, BGRA alpha and row padding.
- Release the camera when a set finishes; reopen it for a new set and clear stale recording-quality state on relevant stop/switch paths.
- Remove the four first-run introductory slides, their exclusive screen/widget and 12 PNGs. Splash, authentication, shared branded components and profile setup remain.

## Issue status and independent evidence

| Issue | Root cause / solution | Status and evidence | Remaining risk |
|---|---|---|---|
| FC-01 Correction authority | Empty rules could still produce valid/correct results. Introduced tracking verdict, per-rep ledger and an experimental two-rule curl slice. | Partial. Engine tests prove tracking is not correctness; synthetic sway produces an error and two subsequent clean reps verify improvement. | No independent precision/recall dataset. Curl flag defaults OFF. |
| FC-02 Context / exercise recognition | Registry and fallback choose from metadata; several catalog aliases use the wrong joint. Specific chain profiles now precede generic matches; fallback remains nonjudgmental. | Partial. Registry, bilateral visibility, moving-arm and lower-body tests pass; catalog source check maps 129/141 entries, with 12 intentionally disabled. | Mapping is not accuracy or video recognition. Equipment/contact, arbitrary unseen exercises and learned classification remain unresolved. |
| FC-03 Counting / cue timing | Endpoint persistence, overly broad occlusion poisoning and cue budgets tied to observation. Added independent return persistence, bounded observed-endpoint continuity, and winner-only speech commits. | Implemented, synthetic verification passed: 102 domain cases plus rep/rule tests. | Device end-to-end latency and video rep agreement unmeasured. |
| FC-04 Observation / active side | Fixed-side or averaged drivers could follow a supporting arm; foot chain incorrectly required heel before toe; cropped leg-only poses were rejected. Corrected side windows and profile-scoped quality gates. | Implemented. Real engine tests choose moving right arm in rows and enter live leg-extension tracking without shoulders; missing data remains missing. | Partial visibility, camera motion and multiple people still constrain observability. |
| FC-05 Calibration / learning | Baselines could accept bent/moving poses or the wrong side. Added limits, stability/sample requirements and view confirmation for correction. | Implemented for experimental slice; bad-posture and view-loss tests pass. | No persistent learned model or autonomous adaptation of safe technique. |
| FC-06 Performance / heat | High capture cost and retained camera after completion; device thermal magnitude unknown. Added camera suspension, bounded metrics, pacing and bounded luma sampling. | Implemented; device verification pending. Fake pipeline tests pass. | No measured battery, memory, jank or thermal improvement. RAM capacity alone does not establish processing headroom. |
| FC-07 Frame budget | Single-sample +/- pacing could oscillate; recording cost not budgeted. Added EMA, sustained overload/recovery requirements, bounded samples and recording duty budget. | Unit tests pass for sustained load, recovery and bounds. | Physical encoder/inference contention not benchmarked. |
| FC-08 Lifecycle / recording | Finished sets paused analysis while retaining capture; quality state could persist. Controller suspends capture and resets recording mode. | Existing fake pipeline tests pass for concurrent start, late detection, background suspend and disposal; source lifecycle/recording contracts pass. | Native recording/switch/permission interruptions need Android/iOS tests. |
| FC-09 Coaching / verification | No independent per-rep history or improvement evidence. Added supported-check summary and prescribed-tempo streaks, including tracking-only profiles. | Implemented. Rule-history, tempo, engine and cue widget tests pass. | Anatomical verification enabled only in experimental curl; no false-coaching field measurement. |
| FC-10 Test coverage | Source-string contracts did not establish runtime behavior. Added Dart/Flutter behavior tests, full suite, explicit blocked gates and packaged logs. | Automated gates passed below. | Tests are synthetic or mocked; acceptance dataset and device runs absent. |
| FC-11 Capabilities / view | UI claims exceeded executable checks. Removed unsupported squat/lateral/curl claims, require confirmed view for experimental correction, expose tracking-only results. | Implemented; capability/view tests and analyze pass. | New chain ranges are provisional projected proxies; user technique cannot be fully assessed from 2D pose. |
| FC-12 Privacy | Existing local inference and opt-in recorder require preservation. New evidence/metrics stay session-local and bounded. | Source review: no new frame upload, telemetry endpoint, persistent training store or permission. | Native recorder storage/OS lifecycle still require device verification. |
| INTRO | First login routed to four slides. Splash now routes logged-out users to AuthScreen. | Implemented and verified by full Flutter auth/brand tests and reference checks. | No change to account/profile onboarding; shared splash artwork remains intentionally. |

## Test results and environment

Final runtime: official Flutter **3.47.5**, Dart **3.13.4**, Linux x64. The original `mobile/pubspec.lock` is unchanged. SDK/package provisioning was completed locally; hosted package archives were checked against locked SHA-256 values, followed by `flutter pub get --offline --enforce-lockfile`. `CI=true` avoids the SDK cloud-environment metadata probe. Earlier runs used Flutter 3.38.10 with temporary dependency resolution; those are historical evidence, not the final release environment.

| Gate | Actual result | Evidence in this archive |
|---|---|---|
| Locked dependency resolution | PASS | FORM_COACH_EVIDENCE/flutter-pub-locked-final.log |
| `flutter analyze --no-fatal-infos` | PASS: **No issues found** | FORM_COACH_EVIDENCE/flutter-analyze-final.log |
| `flutter test --no-pub --reporter expanded` | PASS: **169 passed, 1 skipped, 0 failed** | FORM_COACH_EVIDENCE/flutter-test-final.log |
| Pure production-engine regression | PASS: **102 domain cases** (also executed inside Flutter suite; not 102 additional Flutter test cases) | FORM_COACH_EVIDENCE/dart-expanded-final.log |
| All `test/*.test.js` scripts | PASS: **89/89** under Node **24.19.0** | FORM_COACH_EVIDENCE/node-results.json and node logs |
| Python verifier unit suite | PASS: **5 tests** | FORM_COACH_EVIDENCE/python-final.log |
| Android project structural verifier | PASS: embedding v2/resources/audio/wrapper/identity | FORM_COACH_EVIDENCE/android-project-final.log |
| `flutter build apk --debug --no-pub` | BLOCKED: **No Android SDK found** | FORM_COACH_EVIDENCE/flutter-apk-final.log |
| Native Android/iOS integration, recording and thermal | NOT RUN: no connected physical devices or native SDK environment | Device matrix below |
| Per-error precision/recall and false cues/minute | NOT MEASURED: no independent labeled error corpus or native post-change replay | Accuracy matrix below |

The single skipped Flutter test is the opt-in screenshot exporter guarded by `EXPORT_BRAND_VISUALS`; ordinary brand, auth and responsive tests ran. The Node project declares 22.x; execution under its exact declared Node major is still an environment compatibility gate. No APK or signed release is included.

Three old Node source assertions initially failed because they expected the previous inline tempo implementation or the old exact return-condition string. They now verify the extracted prescribed-tempo guard and independent return persistence. Runtime behavior is checked by Flutter/Dart tests rather than relying on these string assertions.

## Before / after comparisons

| Measure | Supplied baseline | This delivery | Interpretation |
|---|---|---|---|
| Production-engine synthetic regression | 70 cases passed | 102 cases passed | Expanded coverage, not a measured percentage improvement in real accuracy. |
| Catalog metadata coverage | 126 mapped / 15 disabled | 129 mapped / 12 disabled | Leg-curl family enabled with its own knee-motion profile; mapping is not correctness. |
| No-rule full rep | Could be presented as valid/correct | Tracked only, no anatomical correctness claim | Behavioral distinction verified. |
| Short occlusion after an observed endpoint | Cycle could be discarded/aborted | Count can survive <=200 ms only with continuity and observed endpoint | Synthetic tests; long gaps/missing endpoints still cannot count. |
| Cue budget | Observation could consume budget before arbitration | Only winning cue commits | Unit tests. |
| Luma estimate | Sampled plane bytes including possible chroma/alpha/padding | At most 96 luminance-only samples | Unit tests; not a photometric calibration. |
| Camera at finished set | Analysis paused with capture retained | Capture suspended | Code/fake pipeline evidence; device verification pending. |
| Intro pages | Four slides and three exclusive asset generations | Removed; logged-out route goes to authentication | Source/auth/brand verification. |
| Real rep agreement, cue latency, p50/p95, heat, battery, jank | Not independently measured | Not independently measured | No fabricated numerical improvement. |

## Supplied video review and post-change comparison

Five original clips were reviewed through sampled original frames; a focused curl interval was inspected at all 57 decoded frames between approximately 6–8 seconds. This is not exhaustive frame-by-frame labeling of every clip. Metadata's `90000/1` stream rate for two WhatsApp clips is not a credible actual capture-FPS measurement.

| Clip | Duration | Baseline observation | Post-change evidence |
|---|---:|---|---|
| WhatsApp 12.43.16 | 38.657 s | Curl; visible blurred arm/out-of-frame intervals; wrist returns before displayed 0→1 in inspected interval. | Counter/evidence regressions only; native clip replay not run. |
| WhatsApp 12.43.23 | 10.116 s | Floor press/support/camera context differs from standing curl. | Generic upper-chain tracking remains limited; no contact-aware correction claim. |
| WhatsApp 12.53.26 | 21.812 s | Floor-press mid-set recording; insufficient independent whole-set labels. | No measured before/after rep agreement. |
| Document ending 5131 | 51.721 s | Curl; motion and visibility require per-frame annotation. | Synthetic curl correction evidence, not a scored video benchmark. |
| Document ending 5133 | 42.975 s | Floor press; camera handling/support context. | No native post-change replay. |

Original videos are not duplicated in the archive. Metadata is included. No clip can establish phone temperature, battery drain or real inference latency by itself.

## Exercise / error accuracy matrix

| Exercise family | Enabled behavior | Error evidence | Independent precision/recall |
|---|---|---|---|
| Ordinary standing/seated curl | Default tracking; experimental correction only with `FORM_COACH_CURL_CORRECTION=true` | Projected torso sway / elbow drift versus constrained neutral calibration; synthetic sway→error→two clean reps test | NOT MEASURED; default flag OFF, >=90% per-error precision gate unmet |
| Preacher/incline/Bayesian/supported curl | Tracking only | No claim of standing-curl invariants | N/A for disabled form cues |
| Squat/lunge/leg press; hip hinge | Existing knee/hip movement tracking with repaired shared gates | No anatomical error rules enabled | Rep accuracy unmeasured |
| Press/row/triceps/pulldown | Existing elbow-motion tracking; active-side repair | Supporting-arm counterexample tested; no equipment/contact inference | Rep accuracy unmeasured |
| Leg curl / calf | Specific knee / ankle-foot angle drivers | Registry, missing-data, lower-chain and state-machine tests | Rep accuracy unmeasured |
| Hip adduction / fly / reverse fly | Bilateral knee/elbow separation in projected view | Both sides required; arm cannot drive adduction; synthetic normalized-unit tests | Rep accuracy unmeasured; depth motion can be unobservable |
| Pullover / face pull / shrug | Shoulder-relative elevation / elbow angle / ear–shoulder distance | Mapping, units, full-cycle and gap tests | Rep accuracy unmeasured; head motion can affect shrug proxy |
| Core / uncommon or ambiguous exercises | Limited existing metadata proxies or unsupported fallback | No blanket corrective authority | Requires dedicated profiles and labeled video; woodchop/ab-wheel proxies remain limited |
| All rep-based profiles with prescribed tempo | Timing warning after repeated fast reps; later improvement evidence | Tempo and actual production-engine tests | Native false-cue rate unmeasured; no prescribed target means no timing judgment |

## Device / performance / thermal matrix

| Device class | 5/10/20 min, recording OFF/ON | Latency/FPS/memory/jank | Battery / temperature | Status |
|---|---|---|---|---|
| User's 8 GB RAM phone (model/OS unknown) | Not run | Not measured | Not measured | Device unavailable |
| Low / mid / high Android | Not run | Not measured | Not measured | Device/Android SDK unavailable |
| iPhone / iOS | Not run | Not measured | Not measured | Device/Xcode unavailable |

The debug panel now exposes local aggregate processing p50/p95 and intentional pacing versus busy drops. Compare `FORM_COACH_ANALYSIS_FPS=8/10/12/15` at unchanged camera framing/resolution on hardware; default remains 15. These processing metrics exclude camera exposure, display and speech latency, and do not measure temperature. Recording requires a separate device pass.

## Changes by file group

- `domain/form_coach_engine.dart`, `assessment.dart`, `correction_history.dart`, `tempo_coach.dart`: evidence, verdict, per-rep outcomes, prescribed timing, calibration and side selection.
- `domain/form_rule.dart`, `rep_cycle.dart`: observation versus spoken-cue budget, continuity, return persistence and unit-scaled motion thresholds.
- `domain/form_profile.dart`, `readiness.dart`, `metric_spec.dart`, `pose_quality_gate.dart`: calibration contracts, correction view confirmation, bilateral distances, lower-body anchor and independent foot branches.
- `profiles/chain_tracking_profiles.dart`, `form_profile_registry.dart`, `catalog_form_profiles.dart`, `fallback_form_engine.dart`: movement-specific metadata matching and shared active-side tracking.
- `profiles/curl_correction_profile.dart`: experimental, explicitly gated slice; `biceps_curl_profile.dart`, `bodyweight_squat_profile.dart`, `lateral_raise_profile.dart`: accurate capability copy.
- `runtime/analysis_pacing.dart`, `camera_image_conversion.dart`, `camera_pose_pipeline.dart`, `form_coach_controller.dart`: bounded work/metrics, brightness, recording state and capture lifetime.
- `ui/form_coach_screen.dart`, `widgets/debug_panel.dart`, `widgets/pose_overlay.dart`: honest tracking/check summaries and local diagnostics.
- Splash routing, removed intro screen/widget/assets and pubspec entries; obsolete intro tests removed/trimmed, shared tests preserved.
- New Flutter tests in `mobile/test/features/form_coach/`, `form_coach_correction_history_test.dart`, `form_coach_curl_slice_test.dart`; existing counter/domain and Node contracts updated.
- Exact added/modified/deleted file list: `FORM_COACH_EVIDENCE/changed-files.txt`. Formatting accompanies some touched Dart code; unrelated formatting-only files were restored.

## Deviations, rollback and next acceptance step

The user's expanded scope superseded a curl-only effort. Shared fixes, tempo feedback and eight movement families were added, but unvalidated anatomical rules were not enabled across all muscles. Native scientific and thermal gates could not be replaced by unit tests. Installing Flutter and resolving locked dependencies was completed; Android SDK/device gates remain blocked as recorded.

No backend schema/API change, cloud inference, remote training data collection or persistent learned user model was introduced. Evidence/history is session-local and bounded. Existing opt-in recording behavior is retained.

Rollback: restore the original supplied v4 ZIP for a complete rollback. Keep `FORM_COACH_CURL_CORRECTION` absent/false to leave the experimental slice disabled. Use the original files listed in the manifest to revert pacing/lifecycle or onboarding as a group; changing only a summary field or enum consumer in isolation is not a safe rollback. Default FPS is unchanged.

Next acceptance step: independently label complete original/new exercise videos per rep and per supported error; run native replay and real camera sessions, then score each error on held-out subjects/camera positions. Enable a correction rule only after its own precision/recall, cannot-assess, latency and device thermal gates pass. Implement observed exercise classification and contact/equipment context only with a separately validated model/dataset, not metadata matching presented as learning.
