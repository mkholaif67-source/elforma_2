# Phase 2 + Phase 3 Runtime Verification Checklist

This checklist is required before release. JavaScript regression is automated; Flutter/Dart and physical-device checks remain release-gate checks because the current sandbox has no Flutter or Dart SDK.

## Phase 2 — Coach Decision / Why the plan changed?

- [ ] Create two test accounts with different weight/adherence histories.
- [ ] Confirm an on-track account receives `decisionExplanation.available=false` only when data is insufficient, and never receives a fabricated plateau reason.
- [ ] Confirm a plateau caused by adherence shows the real adherence percentage and the same cause key used by the safety decision.
- [ ] Confirm a sleep/NEAT cause blocks a calorie decrease and the explanation says what blocked it.
- [ ] Confirm the explanation, observed signals, and final decision belong to the logged-in account after logout/login.
- [ ] Confirm smart-coach off returns a hold decision with `blockedBy=smart_coach_off` and no adaptive target.
- [ ] Confirm a refresh/retry returns the same decision without mutating the plan on a GET.
- [ ] Confirm the meal-plan and analysis cards use the normalized explanation fields and do not show an empty cause.

## Phase 3 — Pre-Workout Readiness

- [ ] Start a normal training session and verify readiness returns `normal`, `sessionOnly=true`, and `planMutation=false`.
- [ ] Use high recent load plus poor sleep/stress and verify `reduce_load` without changing the saved workout plan.
- [ ] Close and reopen the app during the active session; verify the same account/session readiness is restored.
- [ ] Finish the session, open readiness without a new active session, and verify `dayReset=true` with no readiness decision.
- [ ] Submit readiness twice; verify the second response is idempotent and does not create another row.
- [ ] Verify workout session count, sets, weights, progress history, and plan JSON are unchanged by readiness calls.
- [ ] Start a rest-day session only in a staging build and verify the decision is `keep_rest`, `canTrain=false`, and no exercise is enabled.
- [ ] Switch accounts and verify the previous account's readiness cannot be read with the new account.
- [ ] Verify the readiness card labels the decision as session-only and never presents it as a permanent plan change.

## Performance / thermal checks

- [ ] Run 20 minutes of Form Coach preview with recording off: monitor temperature, dropped frames, and battery.
- [ ] Run one recorded set: verify the local video is saved in `Movies/ElForma/Form Coach`, no upload occurs, and the file is playable.
- [ ] Repeat on the lowest supported Android device and with low battery; verify the app remains responsive.
- [ ] Verify camera preview stays at the device's selected camera quality and that recording is not transcoded in the app.
