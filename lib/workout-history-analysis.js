'use strict';

// Read-only presentation model for the trainee's workout log.
// It never changes plans, progression rules or saved sessions. It only groups
// already-completed sessions into local calendar weeks and derives transparent
// comparisons from the exact sets the Smart Coach already consumes.

const DAY_MS = 86400000;

function finite(value, fallback) {
  const n = Number(value);
  return Number.isFinite(n) ? n : (fallback == null ? 0 : fallback);
}

function rounded(value, digits) {
  const scale = Math.pow(10, digits == null ? 1 : digits);
  return Math.round(finite(value) * scale) / scale;
}

function localWeekKey(value, offsetMinutes) {
  const time = Date.parse(value);
  if (!Number.isFinite(time)) return null;
  const shifted = new Date(time + offsetMinutes * 60000);
  shifted.setUTCHours(0, 0, 0, 0);
  const mondayOffset = (shifted.getUTCDay() + 6) % 7;
  shifted.setUTCDate(shifted.getUTCDate() - mondayOffset);
  return shifted.toISOString().slice(0, 10);
}

function addDays(day, count) {
  const value = new Date(day + 'T00:00:00.000Z');
  value.setUTCDate(value.getUTCDate() + count);
  return value.toISOString().slice(0, 10);
}

function completedSets(session) {
  return Array.isArray(session && session.sets)
    ? session.sets.filter(set => set && (set.completed === 1 || set.completed === true))
    : [];
}

// Epley is used only inside its reasonable display range. Bodyweight/assisted
// movements and very high-rep sets are excluded instead of presenting a fake
// strength number.
function estimatedOneRepMax(set) {
  const weight = finite(set && set.weight);
  const reps = finite(set && set.reps);
  if (weight <= 0 || reps < 1 || reps > 12) return null;
  return rounded(weight * (1 + reps / 30), 1);
}

function summarizeSession(session, metadata, groupLabels) {
  const sets = completedSets(session).map(set => {
    const meta = metadata[set.exercise_name] || {};
    const muscleKey = meta.group || meta.muscle || 'other';
    return Object.assign({}, set, {
      muscleKey,
      muscleName: groupLabels[muscleKey] || meta.muscle || 'عضلات متعددة',
      e1rm: estimatedOneRepMax(set)
    });
  });
  const exercises = new Map();
  for (const set of sets) {
    const key = String(set.exercise_key || set.exercise_name || 'exercise');
    const row = exercises.get(key) || {
      exerciseKey: key,
      name: String(set.exercise_name || 'تمرين'),
      muscleKey: set.muscleKey,
      muscleName: set.muscleName,
      sets: [],
      volume: 0,
      bestE1rm: null
    };
    row.sets.push(set);
    row.volume += finite(set.weight) * finite(set.reps);
    if (set.e1rm != null && (row.bestE1rm == null || set.e1rm > row.bestE1rm)) row.bestE1rm = set.e1rm;
    exercises.set(key, row);
  }
  for (const row of exercises.values()) row.volume = rounded(row.volume, 1);
  return Object.assign({}, session, {
    sets,
    setCount: sets.length,
    exerciseCount: exercises.size,
    volume: rounded(sets.reduce((sum, set) => sum + finite(set.weight) * finite(set.reps), 0), 1),
    exercises: [...exercises.values()]
  });
}

function summarizeWeek(key, sessions) {
  const ordered = sessions.slice().sort((a, b) => Date.parse(a.finished_at || a.started_at) - Date.parse(b.finished_at || b.started_at));
  const muscle = new Map();
  const strength = new Map();
  let rirSum = 0, rirCount = 0, duration = 0;
  for (const session of ordered) {
    duration += finite(session.duration_sec);
    for (const set of session.sets) {
      if (set.rir != null && Number.isFinite(Number(set.rir))) { rirSum += Number(set.rir); rirCount++; }
      const m = muscle.get(set.muscleKey) || { key: set.muscleKey, name: set.muscleName, sets: 0, volume: 0 };
      m.sets++;
      m.volume += finite(set.weight) * finite(set.reps);
      muscle.set(set.muscleKey, m);
      if (set.e1rm != null) {
        const exKey = String(set.exercise_key || set.exercise_name);
        const old = strength.get(exKey);
        if (!old || set.e1rm > old.e1rm) strength.set(exKey, { exerciseKey: exKey, name: set.exercise_name, muscleName: set.muscleName, e1rm: set.e1rm });
      }
    }
  }
  const setCount = ordered.reduce((sum, session) => sum + session.setCount, 0);
  const volume = rounded(ordered.reduce((sum, session) => sum + session.volume, 0), 1);
  return {
    key,
    start: key,
    end: addDays(key, 6),
    sessions: ordered,
    sessionCount: ordered.length,
    setCount,
    exerciseCount: new Set(ordered.flatMap(session => session.exercises.map(exercise => exercise.exerciseKey))).size,
    volume,
    durationSec: duration,
    avgRir: rirCount ? rounded(rirSum / rirCount, 1) : null,
    muscles: [...muscle.values()].map(row => Object.assign(row, { volume: rounded(row.volume, 1) })).sort((a, b) => b.sets - a.sets),
    strength: [...strength.values()].sort((a, b) => b.e1rm - a.e1rm),
    comparison: null,
    insights: []
  };
}

function pct(current, previous) {
  return previous > 0 ? rounded((current / previous - 1) * 100, 1) : null;
}

function compareWeek(current, previous) {
  if (!previous) {
    current.insights.push({ type: 'baseline', title: 'ده خط الأساس', body: 'بعد أسبوع تدريب آخر هنقدر نقارن الحجم والقوة والعضلات بنفس طريقة التسجيل.' });
    return;
  }
  const previousMuscles = new Map(previous.muscles.map(row => [row.key, row]));
  const muscleChanges = current.muscles.map(row => {
    const before = previousMuscles.get(row.key);
    return Object.assign({}, row, { previousSets: before ? before.sets : 0, deltaSets: row.sets - (before ? before.sets : 0) });
  }).sort((a, b) => Math.abs(b.deltaSets) - Math.abs(a.deltaSets));
  const previousStrength = new Map(previous.strength.map(row => [row.exerciseKey, row]));
  const strengthChanges = current.strength.map(row => {
    const before = previousStrength.get(row.exerciseKey);
    const changePct = before ? pct(row.e1rm, before.e1rm) : null;
    return Object.assign({}, row, { previousE1rm: before ? before.e1rm : null, changePct });
  }).filter(row => row.previousE1rm != null).sort((a, b) => Math.abs(b.changePct) - Math.abs(a.changePct));
  current.comparison = {
    previousWeek: previous.key,
    sessionsDelta: current.sessionCount - previous.sessionCount,
    setsDelta: current.setCount - previous.setCount,
    volumeDeltaPct: pct(current.volume, previous.volume),
    durationDeltaPct: pct(current.durationSec, previous.durationSec),
    muscleChanges,
    strengthChanges
  };
  const volumeDelta = current.comparison.volumeDeltaPct;
  if (volumeDelta != null && volumeDelta >= 10) current.insights.push({ type: 'positive', title: 'حجم العمل ارتفع', body: 'إجمالي الوزن × التكرارات زاد ' + Math.abs(volumeDelta).toFixed(1) + '% عن الأسبوع السابق. راقب جودة الأداء والاستشفاء قبل أي زيادة جديدة.' });
  else if (volumeDelta != null && volumeDelta <= -10) current.insights.push({ type: 'attention', title: 'حجم العمل انخفض', body: 'إجمالي الوزن × التكرارات أقل ' + Math.abs(volumeDelta).toFixed(1) + '% عن الأسبوع السابق. الانخفاض طبيعي لو كان أسبوع تخفيف أو جلسات أقل.' });
  else current.insights.push({ type: 'steady', title: 'الحجم مستقر', body: 'إجمالي حجم العمل قريب من الأسبوع السابق، وده مناسب للتقييم قبل تغيير الحمل.' });

  const improved = strengthChanges.filter(row => row.changePct >= 1).slice(0, 3);
  if (improved.length) current.insights.push({ type: 'positive', title: 'تحسن في القوة التقديرية', body: improved.map(row => row.name + ' +' + row.changePct.toFixed(1) + '%').join(' · ') });
  const declined = strengthChanges.filter(row => row.changePct <= -3).slice(0, 3);
  if (declined.length) current.insights.push({ type: 'attention', title: 'أداء يحتاج متابعة', body: declined.map(row => row.name + ' ' + row.changePct.toFixed(1) + '%').join(' · ') + '. نتيجة أسبوع واحد ليست حكمًا؛ راجع النوم وRIR وجودة التسجيل.' });
  const muscleRise = muscleChanges.filter(row => row.deltaSets > 0).slice(0, 3);
  const muscleDrop = muscleChanges.filter(row => row.deltaSets < 0).slice(0, 3);
  if (muscleRise.length || muscleDrop.length) current.insights.push({ type: 'neutral', title: 'توزيع المجموعات', body: [muscleRise.length ? 'زاد: ' + muscleRise.map(row => row.name + ' +' + row.deltaSets).join('، ') : '', muscleDrop.length ? 'قل: ' + muscleDrop.map(row => row.name + ' ' + row.deltaSets).join('، ') : ''].filter(Boolean).join(' · ') });
}

function buildTrainingWeeks(sessions, metadata, groupLabels, offsetMinutes) {
  const offset = Number.isFinite(Number(offsetMinutes)) ? Number(offsetMinutes) : 180;
  const prepared = (sessions || []).filter(session => session && session.status === 'completed').map(session => summarizeSession(session, metadata || {}, groupLabels || {}));
  const buckets = new Map();
  for (const session of prepared) {
    const key = localWeekKey(session.finished_at || session.started_at, offset);
    if (!key) continue;
    const rows = buckets.get(key);
    if (rows) rows.push(session); else buckets.set(key, [session]);
  }
  const currentKey = localWeekKey(new Date().toISOString(), offset);
  const chronological = [...buckets.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([key, rows]) => {
    const week = summarizeWeek(key, rows);
    week.isCurrent = key === currentKey;
    return week;
  });
  const byKey = new Map(chronological.map(week => [week.key, week]));
  for (const week of chronological) compareWeek(week, byKey.get(addDays(week.key, -7)) || null);
  return chronological.reverse();
}

module.exports = { buildTrainingWeeks, estimatedOneRepMax, localWeekKey };
