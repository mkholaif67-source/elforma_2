'use strict';
// Engine recovery estimate, not a medical measurement. Keep parity test with calcRecovery.
function score(profile){
  const state=Object.assign({},profile,{days:profile.trainingDays,daily:profile.dailyActivity});
  let s=100;
  if(state.sleep==='poor')s-=25;else if(state.sleep==='ok')s-=10;
  if(state.stress==='high')s-=20;else if(state.stress==='mid')s-=10;
  // FIX-6: 5-level daily activity impact on recovery
  if(state.daily==='veryActive')s-=18; // athlete/manual labor = major recovery demand
  else if(state.daily==='active')s-=10;
  else if(state.daily==='light')s-=3;  // light activity slightly reduces recovery cap
  // sedentary = no penalty (most recovery capacity)
  // SCI-FIX-1: Age penalty محكم بجودة النوم — Dattilo et al. 2011
  // النوم هو المحدد الرئيسي للتعافي بعد 40. الكود القديم أعطى penalty ثابتة
  // بغض النظر عن النوم — يعاقب من ينام جيدا وعمره 42 بنفس عقوبة من ينام سيئا
  const _sleepQ = state.sleep==='good' ? 1.0 : state.sleep==='ok' ? 0.7 : 0.45;
  const _age = state.age || 25;
  if(_age > 65)      s -= Math.round(20 * (1 - _sleepQ * 0.5));  // 65+: penalty 10-20
  else if(_age > 55) s -= Math.round(14 * (1 - _sleepQ * 0.4));  // 55-65: penalty 8-14
  else if(_age > 40) s -= Math.round(8  * (1 - _sleepQ * 0.35)); // 40-55: penalty 5-8
  // PATCH 6: Frequency safety cap — high training frequency limits effective recovery ceiling
  const d=state.days||3;
  if(d>=6) s=Math.min(s,82);  // 6 days: cap prevents Arnold on borderline recovery
  else if(d===5) s=Math.min(s,90); // 5 days: soft ceiling, preserves advanced eligibility
  return Math.max(30,s);
}
module.exports={score};
