# ElForma cinematic experience v3

This file is the implementation contract for the nine panels in the approved
second proposal. Runtime code must not fall back to the retired v2 artwork.

## Fixed intro timeline (10 seconds)

| Time | Scene | Owned foreground layers | Motion |
| --- | --- | --- | --- |
| 0.0–2.0s | Seed | `intro_seed` | Vertical light opens, seed is revealed bottom-to-top, particles and leaves rise |
| 1.7–4.0s | Sport | `runner_00..05` | Real six-frame run cycle, rightward travel, animated energy trail |
| 3.7–6.2s | Nutrition | `ingredient_00..07`, `intro_food_final` | Ingredients fall independently, rotate and spiral into the final bowl |
| 5.9–8.1s | Merge | `intro_merge_energy`, `brand_mark` | Two light streams converge, athlete mark forms in the collision |
| 7.8–10.0s | Brand | `intro_logo_ground`, `logo.png` | Leaves cross, logo fragments assemble, glow settles, tagline appears |

Scene overlaps are intentional transitions, not simultaneous full-opacity
cards. The timeline is always allowed to finish. Network/bootstrap work runs in
parallel and cannot shorten it; slow startup holds only the settled final frame.

## First-run onboarding (four pages)

| Page | Exact title | Subtitle | Owned artwork |
| --- | --- | --- | --- |
| Brand | دائمًا أفضل نسخة منك | رحلتك تبدأ الآن | `onboarding_brand_ground` + illuminated app logo |
| Sport | أقوى نسخة منك | برنامج تمرين يناسب مستواك وهدفك | `onboarding_sport` |
| Nutrition | غذاؤك وقودك | تغذية متوازنة تناسب يومك وهدفك | `onboarding_nutrition` |
| Health | صحة أفضل لحياة أطول | عادات بسيطة تصنع فرقًا كل يوم | `onboarding_health` |

User-facing strings have no terminal punctuation. Each foreground artwork is
exclusive to its page. The botanical background system is shared, but its
lighting, leaf placement and motion vary per scene.
