'use strict';

const assert = require('node:assert/strict');
const { buildTrainingWeeks, estimatedOneRepMax, localWeekKey } = require('../lib/workout-history-analysis');

const metadata = {
  'Bench Press': { group: 'chest', muscle: 'chest' },
  'Lat Pulldown': { group: 'back', muscle: 'back' }
};
const labels = { chest: 'الصدر', back: 'الظهر' };

function set(name, number, weight, reps, rir, completed = true) {
  return {
    exercise_key: name.toLowerCase().replaceAll(' ', '_'),
    exercise_name: name,
    set_number: number,
    weight,
    reps,
    rir,
    completed: completed ? 1 : 0
  };
}

const sessions = [
  {
    id: 1, status: 'completed', day_name: 'Push',
    started_at: '2026-08-03T17:00:00.000Z', finished_at: '2026-08-03T18:00:00.000Z', duration_sec: 3600,
    sets: [set('Bench Press', 1, 90, 8, 2), set('Bench Press', 2, 90, 8, 1), set('Bench Press', 3, 100, 5, 1, false)]
  },
  {
    id: 2, status: 'completed', day_name: 'Pull',
    started_at: '2026-08-05T17:00:00.000Z', finished_at: '2026-08-05T18:00:00.000Z', duration_sec: 3600,
    sets: [set('Lat Pulldown', 1, 70, 10, 2)]
  },
  {
    id: 3, status: 'completed', day_name: 'Push',
    started_at: '2026-08-10T17:00:00.000Z', finished_at: '2026-08-10T18:00:00.000Z', duration_sec: 3600,
    sets: [set('Bench Press', 1, 95, 8, 1), set('Bench Press', 2, 95, 15, 0)]
  },
  {
    id: 4, status: 'active', day_name: 'Future/unfinished',
    started_at: '2026-08-12T17:00:00.000Z', finished_at: null, duration_sec: 0,
    sets: [set('Lat Pulldown', 1, 80, 10, 1)]
  }
];

const weeks = buildTrainingWeeks(sessions, metadata, labels, 180);
assert.equal(weeks.length, 2, 'only calendar weeks with completed sessions should exist');
assert.equal(weeks[0].sessionCount, 1, 'active/uncompleted days must not appear');
assert.equal(weeks[1].sessionCount, 2);
assert.equal(weeks[1].setCount, 3, 'uncompleted sets must not appear');
assert.equal(weeks[0].sessions[0].exercises[0].sets.length, 2);
assert.equal(weeks[0].comparison.previousWeek, weeks[1].key);
assert.ok(weeks[0].comparison.volumeDeltaPct > 0);
assert.equal(weeks[0].strength[0].e1rm, estimatedOneRepMax(set('Bench Press', 1, 95, 8, 1)));
assert.equal(weeks[0].strength.length, 1, '15-rep set should not create an e1RM estimate');
assert.equal(localWeekKey('2026-08-09T22:30:00.000Z', 180), '2026-08-10', 'week grouping must use the trainee local offset');
assert.ok(weeks[0].insights.length >= 2, 'weekly coach insights should be generated');

console.log('Workout history weekly grouping and analysis passed');
