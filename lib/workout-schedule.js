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
function dayKey(day){return day&&typeof day==='object'?String(day.key||day.dayKey||day.name||'').trim():'';}
function firstWorkoutDay(planData){
  const wanted=String(planData&&planData._firstWorkoutDayKey||'').trim();
  const buckets=[planData&&planData._onboardingWeek,planData&&planData._regularWeek,planData&&planData.plan];
  for(const bucket of buckets){
    if(!Array.isArray(bucket))continue;
    const found=wanted?bucket.find(day=>dayKey(day)===wanted):bucket.find(isTrainingDay);
    if(found&&isTrainingDay(found))return found;
  }
  return null;
}
function firstWorkoutCompleted(planData,sessions){
  if(planData&&planData._firstWorkoutCompleted===true)return true;
  const wanted=String(planData&&planData._firstWorkoutDayKey||'').trim();
  if(!wanted||!Array.isArray(sessions))return false;
  return sessions.some(session=>session&&session.status!=='active'&&String(session.day_key||session.dayKey||'').trim()===wanted);
}

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
  let next=0;
  if(selected.length){
    // Fixed weekdays are authoritative. A new user created on a rest weekday
    // stays in a pre-start/rest state until the first selected day.
    for(let delta=0;delta<onboardingDays&&next<sessions.length;delta++){
      const weekday=todayWeekday+delta;
      if(selected.includes(weekday))onboarding[delta]=sessions[next++];
    }
  }else{
    onboarding[0]=sessions[0];
    const rotated=rotateToFirstWorkout(planData.plan);
    for(let i=1;i<onboardingDays;i++)onboarding[i]=rotated[i]||rest();
  }

  let firstWorkoutDelta=0;
  if(selected.length){
    firstWorkoutDelta=selected.reduce((best,weekday)=>{
      const delta=(weekday-todayWeekday+7)%7;
      return delta<best?delta:best;
    },7);
    if(firstWorkoutDelta===7)firstWorkoutDelta=0;
  }

  planData._onboardingWeek=onboarding;
  planData._regularWeek=regular;
  planData._regularUsesWeekdays=selected.length>0;
  planData._onboardingDays=onboardingDays;
  planData.plan=onboarding;
  planData.selectedDays=selected;
  planData._scheduleStartDate=dateOnly(todayLocal);
  planData._scheduleStartedMs=todayLocal-offsetMs;
  planData._firstWorkoutDate=dateOnly(todayLocal+firstWorkoutDelta*DAY_MS);
  planData._firstWorkoutDayKey=dayKey(sessions[0]);
  // This marker is deliberately persisted with the plan. It distinguishes the
  // one-time new-account exception from an established user's normal schedule.
  // Callers that continue an existing plan pass the old value explicitly.
  if(Object.prototype.hasOwnProperty.call(opts,'firstWorkoutException')){
    planData._firstWorkoutExceptionActive=opts.firstWorkoutException===true;
  }else if(!Object.prototype.hasOwnProperty.call(planData,'_firstWorkoutExceptionActive')){
    planData._firstWorkoutExceptionActive=true;
  }
  planData._onboardingEndsDate=dateOnly(todayLocal+onboardingDays*DAY_MS);
  return{planData,scheduleStartDate:planData._scheduleStartDate,firstWorkoutDate:planData._firstWorkoutDate,selectedDays:selected};
}

function phaseFor(planData,options){
  const opts=options||{},nowMs=Number.isFinite(opts.nowMs)?opts.nowMs:Date.now(),offsetMs=Number.isFinite(opts.offsetMs)?opts.offsetMs:3*3600000;
  const todayLocal=localToday(nowMs,offsetMs),started=Number(planData&&planData._scheduleStartedMs);
  const elapsed=Number.isFinite(started)?Math.max(0,Math.floor((nowMs-started)/DAY_MS)):0;
  const onboardingDays=Math.max(1,Number(planData&&planData._onboardingDays)||7);
  let phase;
  if(planData&&Array.isArray(planData._regularWeek)&&elapsed>=onboardingDays){
    if(planData._regularUsesWeekdays){
      const weekday=saturdayIndexForLocalDay(todayLocal),weekStart=todayLocal-weekday*DAY_MS;
      phase={days:planData._regularWeek,index:weekday,phase:'regular',startDate:dateOnly(weekStart)};
    }else{
      const regularLength=Math.max(1,planData._regularWeek.length),cycleDay=(elapsed-onboardingDays)%regularLength,cycleStart=todayLocal-cycleDay*DAY_MS;
      phase={days:planData._regularWeek,index:cycleDay,phase:'regular',startDate:dateOnly(cycleStart)};
    }
  }else{
    const days=Array.isArray(planData&&planData._onboardingWeek)?planData._onboardingWeek:(planData&&planData.plan)||[];
    phase={days,index:days.length?elapsed%days.length:0,phase:'onboarding',startDate:planData&&planData._scheduleStartDate};
  }
  // Calendar progression must not consume Workout 1 for a new account. Keep
  // rest days/rest spacing intact, but on every scheduled training day expose
  // the same first unit until a completed session is persisted.
  const holdFirst=planData&&planData._firstWorkoutExceptionActive===true&&!firstWorkoutCompleted(planData,opts.completedSessions);
  const current=phase.days&&phase.days[phase.index];
  const first=holdFirst?firstWorkoutDay(planData):null;
  if(first&&isTrainingDay(current)){
    const heldDays=phase.days.slice();heldDays[phase.index]=first;
    return Object.assign({},phase,{days:heldDays,firstWorkoutHeld:true});
  }
  return phase;
}
function materializePlan(planData,options){
  if(!planData||typeof planData!=='object')return planData;
  const opts=options||{},nowMs=Number.isFinite(opts.nowMs)?opts.nowMs:Date.now(),offsetMs=Number.isFinite(opts.offsetMs)?opts.offsetMs:3*3600000;
  const phase=phaseFor(planData,{nowMs,offsetMs,completedSessions:opts.completedSessions});
  if(Array.isArray(phase.days)&&phase.days.length)planData.plan=phase.days;
  const todayLocal=localToday(nowMs,offsetMs),todayDay=phase.days&&phase.days[phase.index];
  planData._schedulePhase=phase.phase;
  planData._scheduleDayIndex=phase.index;
  planData._scheduleTodayDate=dateOnly(todayLocal);
  planData._scheduleIsRest=!isTrainingDay(todayDay);
  planData._schedulePendingStart=Boolean(planData._firstWorkoutDate&&planData._firstWorkoutDate>dateOnly(todayLocal));
  if(phase.startDate)planData._scheduleStartDate=phase.startDate;
  return planData;
}
function trainingDayForNow(planData,options){const phase=phaseFor(planData,options),day=phase.days&&phase.days[phase.index];return day?isTrainingDay(day):null;}
module.exports={DAY_MS,isTrainingDay,normalizePreferredDays,saturdayIndexForLocalDay,alignPlan,phaseFor,materializePlan,trainingDayForNow,dayKey,firstWorkoutCompleted};
