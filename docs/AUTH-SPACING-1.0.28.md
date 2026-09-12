# Login and signup spacing adjustment

Removed the chevron and its trailing spacer from the shared bottom mode-switch link

The hero photo now fades to the existing canvas before the logo, with 10 reference pixels of clear space above it. The logo retains its original position and size. The photos retain their original dimensions and placement. Removed the obsolete signup-only radial cover because the shared photo fade now handles separation in both modes

Login fade: y163–193, logo starts y203
Signup fade: y155–185, logo starts y195

Fields, form actions, mode switching, password visibility and country picker behavior remain unchanged

Verified source diff, fade geometry and existing source/version/CI gates. No new Flutter runtime or APK build was performed for this small layout revision
