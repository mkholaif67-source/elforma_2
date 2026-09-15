'use strict';
// ============================================================
//  Engine Worker Thread
//  يشتغل في thread منفصل عشان computeMealPlan (631ms) ما يجمّدش
//  الـ event loop الرئيسي وباقي الطلبات تفضل شغّالة.
//  كل worker عنده نسخته الخاصة من الـ engine (vm context منفصل).
// ============================================================
const { workerData, parentPort } = require('worker_threads');
const host = require('./nutrition-engine-host');

parentPort.on('message', function (msg) {
  const { id, profile, inputs, type } = msg;
  try {
    let result;
    if (type === 'targets') {
      result = host.computeTargets(profile, inputs || {});
    } else {
      result = host.computeMealPlan(profile, inputs || {});
    }
    parentPort.postMessage({ id, ok: true, result });
  } catch (e) {
    parentPort.postMessage({ id, ok: false, error: String(e && e.message || e) });
  }
});

// جاهز
parentPort.postMessage({ ready: true });
