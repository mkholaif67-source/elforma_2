'use strict';

// Canonical workout-calendar alignment.
// preferredDays uses the mobile/onboarding contract: Saturday=0 .. Friday=6.
const DAY_MS = 86400000;

function isTrainingDay(day) {
  return !!(day && day.isRest !== true && Array.isArray(day.exercises) &&
    !/^\s*rest\b/i.test(String(day.name || '')) &&
    !/راحة|تعافي/.test(String(day.name || '')));
}

function normalizePreferredDays(value) {
  if (!Array.isArray(value)) return [];
  return Array.from(new Set(value.map(Number)
    .filter(function (d) { return Number.isFinite(d) && d >= 0 && d <= 6; })
    .map(Math.round))).sort(function (a, b) { return a - b; });
}

function saturdayIndexForLocalDay(localDayStartMs) {
  // localDayStartMs is an artificial UTC midnight carrying the local date.
  // JS Sunday=0..Saturday=6 -> Egyptian Saturday=0..Friday=6.
  return (new Date(localDayStartMs).getUTCDay() + 1) % 7;
}

function dateOnly(localDayStartMs) {
  return new Date(localDayStartMs).toISOString().slice(0, 10);
}

function alignPlan(planData, preferredDays, options) {
  if (!planData || typeof planData !== 'object') throw new Error('plan_required');
  const opts = options || {};
  const nowMs = Number.isFinite(opts.nowMs) ? opts.nowMs : Date.now();
  const offsetMs = Number.isFinite(opts.offsetMs) ? opts.offsetMs : 3 * 3600000;
  const todayLocal = Math.floor((nowMs + offsetMs) / DAY_MS) * DAY_MS;
  const selected = normalizePreferredDays(preferredDays);
  let startLocal = todayLocal;
  let firstWorkoutLocal = todayLocal;

  if (selected.length && Array.isArray(planData.plan)) {
    const sessions = planData.plan.filter(isTrainingDay);
    if (!sessions.length) throw new Error('training_days_missing');
    if (selected.length !== sessions.length) throw new Error('preferred_days_count_mismatch');

    const today = saturdayIndexForLocalDay(todayLocal);
    let rotation = 0;
    let smallestDelta = 8;
    selected.forEach(function (day, index) {
      const delta = (day - today + 7) % 7;
      if (delta < smallestDelta) { smallestDelta = delta; rotation = index; }
    });

    const rest = function () { return { name: 'يوم راحة', isRest: true, exercises: [] }; };
    const week = Array.from({ length: 7 }, rest);
    selected.forEach(function (weekday, index) {
      const sessionIndex = ((index - rotation) % selected.length + selected.length) % selected.length;
      week[weekday] = sessions[sessionIndex];
    });
    planData.plan = week;
    planData.selectedDays = selected;
    startLocal = todayLocal - today * DAY_MS; // current week's Saturday
    firstWorkoutLocal = todayLocal + smallestDelta * DAY_MS;
  } else if (Array.isArray(planData.plan) && planData.plan.length) {
    // No fixed weekdays: start immediately from the split's first real session.
    const first = planData.plan.findIndex(isTrainingDay);
    if (first < 0) throw new Error('training_days_missing');
    if (first > 0) planData.plan = planData.plan.slice(first).concat(planData.plan.slice(0, first));
    delete planData.selectedDays;
  }

  planData._scheduleStartDate = dateOnly(startLocal);
  planData._scheduleStartedMs = startLocal - offsetMs;
  planData._firstWorkoutDate = dateOnly(firstWorkoutLocal);
  return {
    planData: planData,
    scheduleStartDate: planData._scheduleStartDate,
    firstWorkoutDate: planData._firstWorkoutDate,
    selectedDays: selected
  };
}

module.exports = {
  DAY_MS,
  isTrainingDay,
  normalizePreferredDays,
  saturdayIndexForLocalDay,
  alignPlan
};
