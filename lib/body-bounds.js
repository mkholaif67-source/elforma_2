'use strict';
const BOUNDS = Object.freeze({
  age: { min: 7, max: 80, label: 'العمر', code: 'engine_implausible_age' },
  height: { min: 100, max: 250, label: 'الطول', code: 'engine_implausible_height' },
  weight: { min: 25, max: 350, label: 'الوزن', code: 'engine_implausible_weight' },
});
function validateBody(profile) {
  const p = profile || {};
  for (const key of Object.keys(BOUNDS)) {
    const spec = BOUNDS[key], value = Number(p[key]);
    if (!Number.isFinite(value) || value < spec.min || value > spec.max) {
      return { key, code: spec.code, message: 'قيمة غير منطقية ل' + spec.label + ' راجع بياناتك' };
    }
  }
  return null;
}
module.exports = { BOUNDS, validateBody };
