# Form Coach implementation plan — 2026-09-23

Status: recorded before production edits. User authorized execution, including removal of the four introductory slides. No approval pause is required.

## Architecture and evidence
Camera stream -> paced, single-flight conversion -> on-device ML Kit base pose detector -> subject/quality/readiness gates -> separate analysis and visual One Euro filters -> metric evaluator -> RepCounter -> FormRuleTracker -> cue arbitration -> runtime snapshot/overlay/audio -> temporary set summary. Local opt-in recorder shares camera. There is no custom trained movement classifier. Registry/fallback use exercise metadata, not learned video recognition.

All nine existing `test/form-coach*.test.js` source-contract scripts passed before changes. These do not execute Flutter. Flutter is absent initially; installation is being attempted. No Android/iOS device, native ML Kit runtime, thermal or battery instrumentation is attached.

Profiles: biceps is limited but has zero rules; incline press is tracking-only. Catalog/fallback tracking must not be interpreted as exercise-specific correction. Audit engine behavior independently of profile labels.

## Video baseline
Five original phone screen recordings inspected at overview timestamps; these are not native camera frames or labeled clinical evidence. Per-video durations/geometry are in PROJECT_AUDIT/form-coach-evidence/video-metadata.json. `r_frame_rate=90000/1` in some containers is a timebase artifact, not measured analysis FPS.

- 12.43.16 (38.66s): EZ curl, oblique/side camera; moving arm blur and occasional reach outside view; observed displayed counters 0, 1, 3, 5, 6 at overview frames. A detailed consecutive-original-frame review of 6–8s (57 decoded frames, no periodic sampling) shows the arm returning down before the displayed counter changes 0 -> 1. No exact missed-rep total inferred from contact sheets.
- 12.43.23 (10.12s): floor press, initially readiness then 1 displayed; person sits up and scene shifts near end.
- 12.53.26 (21.81s): floor press, starts with camera/body close, displayed 6 -> 10 then summary. Starts mid-set; cannot infer total attempted reps.
- document …5131 (51.72s): curl, displayed 0 -> 15 then summary/navigation; blur and phone handling at end.
- document …5133 (42.98s): floor press; initial hand/camera occlusion, sitting then lying, displayed 0 -> 10 and summary.

These observations cannot establish per-error precision/recall or thermal cause. Original full-resolution video remains available; no videos will be uploaded as telemetry. Full independent rep/error labeling and post-change native replay are blocked pending native inference and annotation.

## Issue register and change plan
| ID/status | Evidence/root cause | Solution/files | Verification | Alternatives/rollback |
|---|---|---|---|---|
| FC-01 Confirmed | biceps rules empty; completed cycles counted valid without evaluated form rules | form_coach_engine, assessment, UI: separate tracking from assessed correctness; add narrow experimental side-view curl profile and per-rep correction history | synthetic engine/rule/summary tests; native video gate pending | Do not advertise unvalidated rules as proven. New correction slice behind compile-time flag; revert related files |
| FC-02 Partially confirmed | fallback taxonomy exists but only metadata; e.g. lower curl shares generic knee thresholds, no contact detection | fallback: explicit tracking limits, guard unsupported mechanical proxies; counterexample tests | fallback resolution tests | Do not infer tool/support contacts from nonexistent ML Kit landmarks. Preserve known profiles; revert fallback file |
| FC-03 Confirmed | trackers spend all candidate budgets before arbitration; single invalid sample poisons whole rep; endpoint persistence contributes delay | form_rule: observe then commit only winning cue, finite/time continuity; rep_cycle: bounded short-gap continuity only if endpoints observed; preserve amplitude/tempo thresholds | noisy/sustained error, cooldown, sparse samples, short/long occlusion tests | No blind threshold relaxation; restore domain files |
| FC-04 Partially confirmed | within-cycle side lock exists, between-cycle switches may reuse wrong baselines; low FPS reason doesn't block driver/rules | engine: same-side calibration, explicit evidence gates, reset/recalibrate on side changes | side/visibility tests | No fake points/interpolation; revert engine |
| FC-05 Confirmed | countdown baseline samples accept any posture with moderate confidence; no minimum sample/stability gate | engine/profile: baseline constraints, minimum stable samples, session-local only | bad posture/moving calibration tests | Do not learn normal technique from first reps. Revert calibration fields |
| FC-06 Partially confirmed | high capture/15FPS verified; thermal magnitude unmeasured | pipeline: bounded metrics and hysteretic duty-aware pacing; optional 8/10/12 settings for device comparison; retain default capture pending accuracy evidence; controller releases camera after set | fake camera tests, pacing unit tests; device 5/10/20m matrix pending | No claim RAM fixes heat. No default resolution cut without evidence; restore runtime files |
| FC-07 Confirmed | pacing single latency sample, oscillates +15/-5, no recording policy | bounded EMA and cooldown; recording-aware budget, conversion+inference accounting | load/recovery tests | No queue or parallel inference; revert policy |
| FC-08 Partially confirmed | serialized recording exists; finished set only pauses stream, preview camera remains; recording quality flag can remain stale | controller clear quality on stop paths, suspend at finish, restart opens camera | fake camera lifecycle tests + existing tests | Keep recorder implementation; revert lifecycle changes |
| FC-09 Confirmed | cues prioritized but no correction verification or per-rule set summary | per-rep supported check history; two later assessable clean reps required for improvement cue | behavior tests; visual/widget checks where SDK available | Never confirm improvement after unobservable frames; revert ledger/UI |
| FC-10 Confirmed | existing unit/source tests, no supplied independent error labels/device benchmark | new focused behavioral tests and explicit blocked acceptance matrix | all available project gates, record each failure | Synthetic tests are not scientific accuracy. No invented ground truth |
| FC-11 Partially confirmed | view gates exist; profile claims broader than executable rules | narrow side-view profile and accurate capability copy; generic tracking stays nonjudgmental | camera-view and profile tests | No depth/grip/equipment inference claims |
| FC-12 Partially confirmed | inference local, recorder opt-in, no observed frame telemetry in inspected paths | preserve privacy; metrics local aggregates only | source trace and recorder tests | No cloud processing/training data collection |
| INTRO Confirmed | SplashScreen routes first login to four-slide ResponsiveBrandOnboardingScreen | route directly to AuthScreen; remove exclusive screen/widget/assets and update their obsolete tests | reference scan + splash/auth tests | Preserve branded splash, login/register, profile setup, shared brand widgets/assets; revert from original ZIP |

## Dependency order
1. Record plan and baseline (this file); provision SDK.
2. Implement rule/cycle evidence contracts and per-rep ledger, then engine integration.
3. Add constrained experimental curl slice; fix unsupported fallback cases/capability claims.
4. Pacing/metrics/lifecycle repairs without unmeasured default resolution downgrade.
5. Remove intro route and only exclusive resources.
6. Execute Flutter analyze/test, all Node tests individually, Python Android verifier where runnable; compare baseline for failing gates. Package with final report and evidence.

## Measurement and acceptance
Hardware matrix: low/mid/high Android and iOS; 5/10/20 minutes with recording on/off, compare analysis target 8/10/12/15 at unchanged framing. Record p50/p95 conversion/inference/end-to-end, achieved FPS, intentional pacing vs busy drops, memory, jank, battery, thermal status and per-error precision/recall. No fake numeric before/after values.

Curl slice initially experimental: static side view, shoulder/elbow/wrist/hip visible, ordinary standing/seated curl only; supported checks limited to projected upper-arm and torso movement against constrained neutral calibration. Preacher/incline/Bayesian/supported variations remain tracking-only. Rule thresholds are provisional engineering settings, not validated biomechanics. User-facing production enablement requires independent >=90% per-error precision plus acceptable recall and false cues/minute. No unsupervised learning.

No database/API migrations. State remains session-local. Archive original is rollback; per-stage diff is generated. New flags default to existing tracking until experimental correction gates pass. Final status must remain partial / device verification pending if hardware or scientific gates unavailable.

## Expanded scope before additional edits
All muscles: replace incorrect generic body chains for fly, rear fly, calf, leg curl, adduction, pullover, face pull and shrug. Fix shared active-side selection, normalized-unit thresholds, lower-body-only tracking and stride-aware luminance. Verify the production engine with synthetic trajectories per profile; real-video accuracy remains an independent gate. Tempo feedback must use the prescribed session duration and verify later improvement across every profile.
