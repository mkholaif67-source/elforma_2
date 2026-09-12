# Responsive Intro and Onboarding

## Runtime structure

- `mobile/lib/widgets/brand_experience_visual.dart` owns the v3 asset catalogue,
  nine background variants, and the four page-exclusive onboarding visuals.
- `mobile/lib/widgets/brand_intro_scene.dart` owns the fixed ten-second,
  five-scene timeline, real runner frames, falling ingredients, energy merge,
  central athlete mark, flying leaves, and fragmented logo assembly.
- `mobile/lib/screens/responsive_brand_onboarding_screen.dart` owns the four
  first-run pages. Navigation has reserved layout space and cannot overlap the
  page artwork or copy.

## Responsive rules

- Critical artwork always uses `BoxFit.contain` inside bounded regions.
- Transparent foreground layers keep their complete silhouette at every ratio.
- `SafeArea` protects the brand, Arabic copy, pagination, and action button.
- Compact phones reduce copy size and spacing; wide layouts use a two-column
  composition instead of stretching the phone layout.
- Arabic titles and subtitles remain Flutter text and are not baked into images.

## Assets

Runtime assets are the dedicated transparent layers, runner frames, ingredient
objects, and page-exclusive onboarding artwork in
`mobile/assets/cinematic_v3/`. The retired v2 artwork was deleted and has no
runtime or documentation fallback.

## Regression coverage

`mobile/test/brand_experience_responsive_test.dart` covers eight phone/tablet
surfaces from 320×568 through 800×1280, every onboarding visual, the approved
four-page order, and six checkpoints across the cinematic timeline.
