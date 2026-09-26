---
name: Serene Athletic Elegance
colors:
  surface: '#ecfef3'
  surface-dim: '#cdded4'
  surface-bright: '#ecfef3'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#e6f8ed'
  surface-container: '#e0f2e7'
  surface-container-high: '#dbece2'
  surface-container-highest: '#d5e7dc'
  on-surface: '#101e18'
  on-surface-variant: '#414844'
  inverse-surface: '#25342d'
  inverse-on-surface: '#e3f5ea'
  outline: '#717973'
  outline-variant: '#c1c8c2'
  surface-tint: '#3f6653'
  primary: '#012d1d'
  on-primary: '#ffffff'
  primary-container: '#1b4332'
  on-primary-container: '#86af99'
  inverse-primary: '#a5d0b9'
  secondary: '#3e6842'
  on-secondary: '#ffffff'
  secondary-container: '#bfefbe'
  on-secondary-container: '#446e47'
  tertiary: '#152b1c'
  on-tertiary: '#ffffff'
  tertiary-container: '#2a4131'
  on-tertiary-container: '#93ad98'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#c1ecd4'
  primary-fixed-dim: '#a5d0b9'
  on-primary-fixed: '#002114'
  on-primary-fixed-variant: '#274e3d'
  secondary-fixed: '#bfefbe'
  secondary-fixed-dim: '#a4d2a4'
  on-secondary-fixed: '#002107'
  on-secondary-fixed-variant: '#274f2c'
  tertiary-fixed: '#cee9d3'
  tertiary-fixed-dim: '#b3cdb7'
  on-tertiary-fixed: '#092012'
  on-tertiary-fixed-variant: '#354c3b'
  background: '#ecfef3'
  on-background: '#101e18'
  surface-variant: '#d5e7dc'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 48px
    fontWeight: '300'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Manrope
    fontSize: 34px
    fontWeight: '300'
    lineHeight: 42px
    letterSpacing: -0.015em
  headline-lg:
    fontFamily: Manrope
    fontSize: 32px
    fontWeight: '400'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-lg-mobile:
    fontFamily: Manrope
    fontSize: 26px
    fontWeight: '400'
    lineHeight: 34px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Manrope
    fontSize: 22px
    fontWeight: '500'
    lineHeight: 30px
    letterSpacing: -0.005em
  body-lg:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '300'
    lineHeight: 28px
  body-md:
    fontFamily: Manrope
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Manrope
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 20px
  label-lg:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
    letterSpacing: 0.03em
  label-md:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Manrope
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.08em
rounded:
  sm: 0.5rem
  DEFAULT: 1rem
  md: 1.5rem
  lg: 2rem
  xl: 3rem
  full: 9999px
spacing:
  gutter: 1.5rem
  gutter-sm: 1rem
  margin: 3rem
  margin-sm: 1.25rem
  space-xs: 0.375rem
  space-sm: 0.75rem
  space-md: 1.25rem
  space-lg: 2rem
  space-xl: 3.5rem
---

## Brand & Style

This design system embodies serene athletic elegance, intentional stillness, and modern luxury. Designed specifically for an onboarding journey, it transforms the often-taxing process of user setup into a tranquil, meditative ritual. The visual voice is refined, uncluttered, and self-assured—eschewing aggressive gamification and high-saturation patterns in favor of calm breathability, disciplined white space, and gentle visual balance.

The audience consists of wellness-focused, mindful individuals who appreciate quiet luxury, purposeful design, and frictionless interactions. The UI evokes clarity, composure, and empowerment. Drawing from minimal, organic modernism and tactile subtlety, interfaces rely on floating surface cards, borderless structures, light typography, and soft physical affordances that guide users effortlessly from one milestone to the next.

## Colors

The palette establishes an organic equilibrium through natural earth tones, warm mineral foundations, and foliage-tinted accents:

- **Background Canvas & Tiers:** 
  - Primary Base: `#FAF9F6` (Alabaster cream)
  - Card & Container Surfaces: `#FFFFFF` (Pure white for floating lift)
  - Muted Insets & Secondary Tiers: `#F4F3EF` (Warm linen stone)
- **Primary Ink & Accents:** 
  - Dominant Headline & Action: `#1B4332` (Deep woodland evergreen)
  - Interactive Hover & Focus: `#2D6A4F` (Verdant forest)
- **Secondary & Accent Hues:** 
  - Accent / Focus Rings: `#8FBC8F` (Subtle botanical sage)
  - Soft Tonal Fill & Selection State: `#A3B18A` (Dry moss)
  - Atmospheric Highlights & Soft Badges: `#D8F3DC` (Morning dew)
- **Neutral Typography & Borders:**
  - Body Text: `#24332C` (Deep desaturated pine neutral)
  - Subtle Labels & Placeholders: `#6C7D73` (Weathered lichen)
  - Border Lines: `#E9E7E1` (Whisper cream outline, used sparingly)

## Typography

Typography prioritizes light weights, generous line heights, and open kerning to establish an airy, peaceful cadence. Manrope delivers geometric balance with warm, humanist nuances, pairing structural stability with organic softness.

- **Headlines:** Set predominantly in lighter weights (300 and 400) to convey understated confidence. Display titles evoke editorial grace without heavy visual mass.
- **Body:** Kept open with ample vertical tracking (`1.6x` line height) to reduce cognitive load during multi-step reading.
- **Labels & Micro-copy:** Rendered with elevated letter spacing and slightly firmer weights (500 and 600) to ensure high legibility at micro scales.

## Layout & Spacing

The layout philosophy follows a focused, floating single-column to dual-column model engineered to isolate single tasks during onboarding:

- **Desktop (min-width: 1024px):** Single-column centered container capped at 560px for focused onboarding forms, or an asymmetric 2-column layout (55% narrative showcase / 45% form card) capped at 1120px. Generous `3rem` margins preserve negative space.
- **Tablet (768px - 1023px):** Fluid centered card spanning 8 columns of a 12-column grid, bounded by `2rem` margins.
- **Mobile (< 768px):** Single-column stacked layout with `1.25rem` margin. Interactive actions anchor cleanly to the safe-area bottom edge.

Elements rely on comfortable breathing room: titles and supportive copy sit separated by `space-sm`, question blocks separate via `space-xl`, and option cards employ `space-md` gaps.

## Elevation & Depth

Visual hierarchy is communicated through floating pure-white surfaces layered over soft cream foundations, rather than heavy borders or multi-tier drop shadows:

- **Base Canvas:** Flat `#FAF9F6` creates a tactile, non-glare plane.
- **Floating Cards:** Grounded by a multi-stop, ambient botanical shadow tinted with muted woodland tones:
  - `0 12px 36px -4px rgba(27, 67, 50, 0.04), 0 4px 12px -2px rgba(27, 67, 50, 0.02)`
- **Interactive Hover & Active States:** Shadow blooms gently outward with subtle vertical travel:
  - `0 18px 42px -6px rgba(27, 67, 50, 0.07), 0 6px 16px -3px rgba(27, 67, 50, 0.03)`
- **Outlines:** Used strictly as faint boundaries (`#E9E7E1` or `rgba(27, 67, 50, 0.06)`) on unselected form elements, dissolving upon active or elevated selection.

## Shapes

The design language uses fully rounded pills and generous curvaceous radii, projecting approachable softness, comfort, and human vitality:

- **Interactive Primary Elements:** Buttons, tags, badges, and toggle switches use `rounded-full` (infinite pill).
- **Cards & Step Modules:** Employ `rounded-xl` (2.5rem / 40px) to form cushioned, pebble-like floating planes.
- **Inputs & Selection Tiles:** Employ `rounded-lg` (1.25rem / 20px) to balance interior content alignment with fluid exterior curvature.

## Components

- **Buttons:**
  - *Primary:* Fully pill-shaped (`rounded-full`), solid `#1B4332` fill, text in `#FFFFFF`, with an ambient forest-tinted shadow (`0 8px 20px -3px rgba(27, 67, 50, 0.22)`). Hover transitions smoothly to `#2D6A4F`.
  - *Secondary / Ghost:* Transparent or `#F4F3EF` background, borderless or framed with a `1px` stroke of `#E9E7E1`, text in `#1B4332`.
- **Selection Chips & Pills:**
  - Default: `#FFFFFF` surface with an ultra-faint `#E9E7E1` hairline border, text `#24332C`.
  - Selected: Tonal background `#D8F3DC`, stroke `#8FBC8F`, text `#1B4332` with a subtle spring-scale micro-interaction.
- **Cards & Choice Modules:**
  - Floating `#FFFFFF` rectangles with `rounded-xl` corners. Hover introduces an elevation bloom. Selection applies an interior highlight ring (`2px solid #8FBC8F`) and a soft `#FAF9F6` interior wash.
- **Input Fields:**
  - Understated pill or cushioned rounded rectangles (`1.25rem`). Fill is `#F4F3EF` with no visible border in resting state. Focus transitions background to `#FFFFFF`, paired with a delicate `1.5px` border in `#8FBC8F` and an ambient glow.
- **Checkboxes & Radios:**
  - Circular selectors for both variants. Checkboxes sit in a `#F4F3EF` bed, filling with `#1B4332` displaying an off-white organic check. Radio buttons use a concentric inner pill in `#1B4332` upon selection.
- **Onboarding Progress Indicators:**
  - Segmented minimalist bar or floating dot indicators using thin pills (`4px` height). Inactive segments use `#E9E7E1`, while active progress fills with a continuous animated gradient from `#8FBC8F` to `#1B4332`.