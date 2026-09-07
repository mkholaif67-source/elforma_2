'use strict';

// Canonical workout-calendar alignment.
// preferredDays: Saturday=0 .. Friday=6.
const DAY_MS=86400000;
function isTrainingDay(day){return !!(day&&day.isRest!==true&&Array.isArray(day.exercises)&&!/^\s*rest\b/i.test(String(day.name||''))&&!/راحة|تعافي/.test(String(day.name||'')));}
function normalizePreferredDays(value){if(!Array.isArray(value))return[];return Array.from(new Set(value.map(Number).filter(d=>Number.isFinite(d)&&d>=0&&d<=6).map(Math.round))).sort((a,b)=>a-b);}
function saturdayIndexForLocalDay(localDayStartMs){return(new Date(localDayStartMs).getUTCDay()+1)%7;}
function dateOnly(ms){return new Date(ms).toISOString().slice(0,10);}
function rest(){return{name:'يوم راحة',isRest:true,exercises:[]};}
function localToday(nowMs,offsetMs){return Math.floor((nowMs+offsetMs)/DAY_MS)*DAY_MS;}
function rotateToFirstWorkout(days){const first=days.findIndex(isTrainingDay);if(first<0)throw new Error('training_days_missing');return first?days.slice(first).concat(days.slice(0,first)):days.slice();}

// الأسبوع الأول يبدأ اليوم بأول وحدة من الـsplit، ولا يعتبر الأيام السابقة فائتة.
// من الأسبوع الثاني يرجع الجدول للتوزيع الأسبوعي الطبيعي.
function alignPlan(planData,preferredDays,options){
  if(!planData||typeof planData!=='object')throw new Error('plan_required');
  const opts=options||{},nowMs=Number.isFinite(opts.nowMs)?opts.nowMs:Date.now(),offsetMs=Number.isFinite(opts.offsetMs)?opts.offsetMs:3*3600000;
  const todayLocal=localToday(nowMs,offsetMs),todayWeekday=saturdayIndexForLocalDay(todayLocal),selected=normalizePreferredDays(preferredDays);
  if(!Array.isArray(planData.plan)||!planData.plan.length)throw new Error('training_days_missing');
  const sessions=planData.plan.filter(isTrainingDay);if(!sessions.length)throw new Error('training_days_missing');
  if(selected.length&&selected.length!==sessions.length)throw new Error('preferred_days_count_mismatch');

  let regular;
  if(selected.length){
    regular=Array.from({length:7},rest);
    selected.forEach((weekday,index)=>{regular[weekday]=sessions[index%sessions.length];});
  }else regular=rotateToFirstWorkout(planData.plan);

  const onboardingDays=7-todayWeekday;
  const onboarding=Array.from({length:onboardingDays},rest);
  onboarding[0]=sessions[0]; // ممنوع أول يوم في جدول جديد يكون راحة أو يبدأ من منتصف الـsplit.
  let next=1;
  if(selected.length){
    for(let delta=1;delta<onboardingDays&&next<sessions.length;delta++){
      const weekday=todayWeekday+delta;
      if(selected.includes(weekday))onboarding[delta]=sessions[next++];
    }
  }else{
    const rotated=rotateToFirstWorkout(planData.plan);
    for(let i=1;i<onboardingDays;i++)onboarding[i]=rotated[i]||rest();
  }

  planData._onboardingWeek=onboarding;
  planData._regularWeek=regular;
  planData._regularUsesWeekdays=selected.length>0;
  planData._onboardingDays=onboardingDays;
  planData.plan=onboarding;
  planData.selectedDays=selected;
  planData._scheduleStartDate=dateOnly(todayLocal);
  planData._scheduleStartedMs=todayLocal-offsetMs;
  planData._firstWorkoutDate=dateOnly(todayLocal);
  planData._onboardingEndsDate=dateOnly(todayLocal+onboardingDays*DAY_MS);
  return{planData,scheduleStartDate:planData._scheduleStartDate,firstWorkoutDate:planData._firstWorkoutDate,selectedDays:selected};
}

function phaseFor(planData,options){
  const opts=options||{},nowMs=Number.isFinite(opts.nowMs)?opts.nowMs:Date.now(),offsetMs=Number.isFinite(opts.offsetMs)?opts.offsetMs:3*3600000;
  const todayLocal=localToday(nowMs,offsetMs),started=Number(planData&&planData._scheduleStartedMs);
  const elapsed=Number.isFinite(started)?Math.max(0,Math.floor((nowMs-started)/DAY_MS)):0;
  const onboardingDays=Math.max(1,Number(planData&&planData._onboardingDays)||7);
  if(planData&&Array.isArray(planData._regularWeek)&&elapsed>=onboardingDays){
    if(planData._regularUsesWeekdays){
      const weekday=saturdayIndexForLocalDay(todayLocal),weekStart=todayLocal-weekday*DAY_MS;
      return{days:planData._regularWeek,index:weekday,phase:'regular',startDate:dateOnly(weekStart)};
    }
    const cycleDay=(elapsed-onboardingDays)%7,cycleStart=todayLocal-cycleDay*DAY_MS;
    return{days:planData._regularWeek,index:cycleDay,phase:'regular',startDate:dateOnly(cycleStart)};
  }
  const days=Array.isArray(planData&&planData._onboardingWeek)?planData._onboardingWeek:(planData&&planData.plan)||[];
  return{days,index:days.length?elapsed%days.length:0,phase:'onboarding',startDate:planData&&planData._scheduleStartDate};
}
function materializePlan(planData,options){
  if(!planData||typeof planData!=='object')return planData;
  const phase=phaseFor(planData,options);if(Array.isArray(phase.days)&&phase.days.length)planData.plan=phase.days;
  planData._schedulePhase=phase.phase;if(phase.startDate)planData._scheduleStartDate=phase.startDate;return planData;
}
function trainingDayForNow(planData,options){const phase=phaseFor(planData,options),day=phase.days&&phase.days[phase.index];return day?isTrainingDay(day):null;}
module.exports={DAY_MS,isTrainingDay,normalizePreferredDays,saturdayIndexForLocalDay,alignPlan,phaseFor,materializePlan,trainingDayForNow};
