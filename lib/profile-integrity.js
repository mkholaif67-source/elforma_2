'use strict';
function repairLegacyMeasurements(p) {
  if (!p || p.measurementSchemaVersion >= 2) return p;
  if (p.waist === 40 && p.neck === 20 && p.hips === 50 && p.bodyFat === 3) {
    return Object.assign({}, p, {waist:null,neck:null,hips:null,bodyFat:null,measurementsNeedReview:true});
  }
  return p;
}
module.exports={repairLegacyMeasurements};
