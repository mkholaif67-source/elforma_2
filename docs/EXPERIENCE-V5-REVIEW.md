# Brand experience V5 — working review

This is a visual review build, with actual Flutter-rendered captures. It is not a claim of pixel-identical reproduction of the raster reference.

The approved references are the light intro 1000752493 and onboarding 1000753011 (brand), 1000753013 (sport), 1000753014 (nutrition), 1000753012 (health).

Native layers: fixed photographic backdrop, separate ground shadow, rear ribbon mesh, individual hero assets, front ribbon mesh, independently positioned leaves, glass badges, native Arabic text, native buttons.

Onboarding uses a 432 x 768 reference canvas with uniform contain scaling in the safe area. Intro uses 432 x 900. There is no image stretching. Background fills the viewport independently.

## Intro timing

| Seconds | Track |
|---|---|
| 0–0.12 | Static background |
| 0.12–1.12 | Logo assembles |
| 0.75–1.35 | Approved tagline |
| 0.68–1.85 | Dumbbell enters from left |
| 0.95–2.10 | Shaker settles from above |
| 1.28–2.50 | Bowl enters from right |
| 1.20–3.65 | Rear/front ribbons draw around objects |
| 1.45–3.85 | Individual leaves, tomato, avocado settle |
| 2.90–4.20 | Three badges and captions |
| 3.10–4.30 | Connecting pulse draws |
| 4.30–5.50 | Final composition holds |

A single local AnimationController owns the sequence. Startup checks run concurrently. Assets decode before its clock starts. Completion of that controller gates navigation; no second wall-clock timer can preempt it. Slow server response does not restart or slow the animation. The completed scene stays visible until navigation or the short connection error.

Onboarding retains the existing once-only preference key. Intro still runs at each cold app launch. Existing authenticated users route to their account normally.

## Asset preparation

Generated bitmap assets use the built-in image generation tool. Mask outputs from that tool are applied as alpha channels when an output includes a checkerboard. Every production cutout is independently decoded and checked for real alpha. Source colors are retained. The intro uses individual tomato and avocado assets; the old multi-item ingredient sheet is not included.

## Validation

- Actual production widgets rendered with Flutter 3.35.7 into four separate 864 × 1536 onboarding PNGs and a 648 × 1350 intro video at 30 fps, exactly 165 frames / 5.5 seconds
- Nine visual contract tests passed, including all four pages at eight phone/tablet sizes and stable object transforms during the final hold
- Analysis of the three production visual modules and visual contract test found no issues
- Asset/copy/timing contract, 12 version gates, 7 source checks, 31 CI configuration checks and 10 release hygiene checks passed
- Full application dependency resolution did not complete before the runtime reset. Full-app Flutter analysis/tests and APK compilation are not verified. The existing workmanager dependency requires Flutter >=3.38. Use Flutter 3.38.10 or newer to run the complete app checks.
- No APK or physical-device frame-time validation yet

## Visual limits

The hero assets were reconstructed as independent transparent layers. The ribbon meshes and glass badges are native drawings, so their detailed shapes differ from the reference illustration. The standing athlete and bowl also have visible illustration differences. Uniform safe-area scaling preserves proportions across tested screen sizes but does not make every screen aspect ratio pixel-identical to the reference.

## Reproduce captures

Run `flutter test --dart-define=EXPORT_BRAND_VISUALS=true test/brand_experience_visual_export_test.dart` from mobile. Captures go to build/brand_review. The optional export test is skipped in normal CI; normal widget tests remain enabled. Review outputs are in review/brand-v5.

