# Approved composition and keyboard behavior — 20 September 2026

## Visual specification before implementation
- Source: user's four-panel reference (1705 × 923). Use its actual illustration regions, not newly generated substitutes. Four independent PNGs, each 400 × 559, preserve the calendar ribbon, nutrition cards, stone podiums, foliage, pose drawing, and progress sign.
- Illustration annotation text remains part of the original artwork; provide equivalent semantic descriptions. Main heading, description, button, and pagination remain real Flutter widgets. This is not a flattened screenshot UI. Original annotation resolution is a limitation on very large displays.
- Cream background, forest ink, existing bundled Arabic regular/bold fonts. Title 28 / 1.4, body 17 / 1.65; don't squeeze Arabic letters or disable accessibility text scaling.
- Remove the substituted badge row. Original annotations belong inside the scenes. Preserve artwork aspect ratio with contain; never stretch or crop its contents.
- Physically left arrow, on the left of the native Arabic button label; explicitly prevent automatic RTL mirroring. Preserve first-run routing and intro duration.
- Normal portrait: illustration above native title/body, footer outside the content scroll. Small/large-text viewports: text remains reachable by scrolling, controls remain reachable. Preserve intrinsic width fix.

## Video observations
The 8.92-second recording shows registration focus moving from name to email to phone. The full hero remains above the fields while the keyboard consumes the lower viewport. Password and actions are consequently below the viewport. Code also explicitly centers password at alignment .65, creating avoidable scrolling.

## Keyboard specification
- Closed keyboard: preserve approved images, colors, logo and layout identity.
- Open keyboard: reclaim decorative header space. Login and registration use different form-space budgets; don't scale fields or the entire page.
- Keep a small logo only when there is sufficient height. Hide descriptive decoration during editing, not input fields or actions.
- Scroll only the minimum needed to reveal the focused field; no unconditional centering. All fields participate, with explicit next-field focus order.
- Inputs keep native 16-point typography and at least 56-point height. Long registration, large text, and short viewports scroll normally; no requirement to squeeze every control above an arbitrary keyboard.
- Restore the normal composition on keyboard dismissal. Preserve validation, autofill, passwords, Google and submit behavior.

## Validation limits
No working Flutter SDK or Android device is available in this execution environment. Dart formatting, source contracts, asset inspection and archive checks can run; Flutter regression tests must run in the existing GitHub workflow. Real Android keyboard transitions still require device verification. Do not label previews as device screenshots or claim 100% rendered parity without that check.
