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
function dayKey(day){return day&&typeof day==='object'?String(day.key||day.dayKey||day.day_key||day.name||'').trim():'';}
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
  const journeyStarted=Number(planData&&planData._scheduleStartedMs);
  return sessions.some(session=>{
    if(!session||String(session.status||'').toLowerCase()!=='completed')return false;
    if(String(session.day_key||session.dayKey||'').trim()!==wanted)return false;
    if(!Number.isFinite(journeyStarted))return true;
    const raw=session.finished_at||session.finishedAt||session.started_at||session.startedAt;
    const at=raw==null?NaN:Date.parse(raw);
    return Number.isFinite(at)&&at>=journeyStarted;
  });
}
function workoutSequence(planData){
  if(Array.isArray(planData&&planData._workoutSequence)&&planData._workoutSequence.some(isTrainingDay))return planData._workoutSequence.filter(isTrainingDay);
  const buckets=[planData&&planData._regularWeek,planData&&planData._onboardingWeek,planData&&planData.plan];
  for(const bucket of buckets){if(!Array.isArray(bucket))continue;const seen=new Set(),out=[];for(const day of bucket){const k=dayKey(day);if(isTrainingDay(day)&&k&&!seen.has(k)){seen.add(k);out.push(day);}}if(out.length)return out;}return[];
}
function sessionTime(session){const raw=session&&(session.finished_at||session.finishedAt||session.started_at||session.startedAt),at=raw==null?NaN:Date.parse(raw);return Number.isFinite(at)?at:NaN;}
function derivedSequenceCount(planData,sessions,startedOverride){
  const seq=workoutSequence(planData);if(!seq.length||!Array.isArray(sessions))return 0;const own=Number(planData&&planData._scheduleStartedMs),override=Number(startedOverride),started=Number.isFinite(override)?override:own;let count=0;
  const rows=sessions.filter(x=>x&&String(x.status||'').toLowerCase()==='completed'&&(!Number.isFinite(started)||(Number.isFinite(sessionTime(x))&&sessionTime(x)>=started))).sort((a,b)=>sessionTime(a)-sessionTime(b));
  for(const row of rows)if(dayKey(row)===dayKey(seq[count%seq.length]))count++;return count;
}
function sequenceCount(planData,sessions){const p=Number(planData&&planData._completedSequenceCount),stored=Number.isFinite(p)&&p>=0?Math.floor(p):0,legacy=planData&&planData._firstWorkoutCompleted===true?1:0;return Math.max(stored,legacy,derivedSequenceCount(planData,sessions));}
function regularSequenceCount(planData,sessions){const p=Number(planData&&planData._regularCompletedSequenceCount),stored=Number.isFinite(p)&&p>=0?Math.floor(p):0,started=Number(planData&&planData._regularStartedMs);return Math.max(stored,derivedSequenceCount(planData,sessions,started));}
function nextWorkoutDay(planData,sessions,regular){const seq=workoutSequence(planData),count=regular?regularSequenceCount(planData,sessions):sequenceCount(planData,sessions);return seq.length?seq[count%seq.length]:null;}
function recordCompletion(planData,session){
  if(!planData||!session||String(session.status||'').toLowerCase()!=='completed')return false;const seq=workoutSequence(planData);if(!seq.length)return false;
  const started=Number(planData._scheduleStartedMs),at=sessionTime(session);if(Number.isFinite(started)&&(!Number.isFinite(at)||at<started))return false;
  const regularStarted=Number(planData._regularStartedMs),regular=Number.isFinite(regularStarted)&&Number.isFinite(at)&&at>=regularStarted;
  const count=regular?regularSequenceCount(planData,[]):sequenceCount(planData,[]);if(dayKey(session)!==dayKey(seq[count%seq.length]))return false;const next=count+1;
  if(regular)planData._regularCompletedSequenceCount=next;else planData._completedSequenceCount=next;
  planData._totalCompletedSequenceCount=Math.max(0,Number(planData._totalCompletedSequenceCount)||0)+1;
  planData._nextWorkoutIndex=next%seq.length;planData._firstWorkoutCompleted=true;planData._firstWorkoutExceptionActive=false;planData._sequenceLastCompletedAt=Number.isFinite(at)?new Date(at).toISOString():null;return true;
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
  planData._workoutSequence=sessions.map(day=>Object.assign({},day));
  const carried=Number(opts.completedSequenceCount);planData._completedSequenceCount=Number.isFinite(carried)&&carried>=0?Math.floor(carried):0;
  planData._nextWorkoutIndex=planData._completedSequenceCount%sessions.length;
  const firstWorkoutException=Object.prototype.hasOwnProperty.call(opts,'firstWorkoutException')
    ?opts.firstWorkoutException===true
    :(Object.prototype.hasOwnProperty.call(planData,'_firstWorkoutExceptionActive')?planData._firstWorkoutExceptionActive===true:true);

  let regular;
  if(selected.length){
    regular=Array.from({length:7},rest);
    selected.forEach((weekday,index)=>{regular[weekday]=sessions[index%sessions.length];});
  }else regular=rotateToFirstWorkout(planData.plan);

  const onboardingDays=7-todayWeekday;
  const onboarding=Array.from({length:onboardingDays},rest);
  if(firstWorkoutException){
    // One bridge week only: start now and follow the split's authored workout /
    // recovery pattern until Friday. The first complete Saturday below starts
    // the official calendar from workout one, independent of bridge progress.
    const rotated=rotateToFirstWorkout(planData.plan);
    for(let i=0;i<onboardingDays;i++)onboarding[i]=rotated[i]||rest();
    onboarding[0]=sessions[0];
  }else if(selected.length){
    let next=0;
    for(let delta=0;delta<onboardingDays&&next<sessions.length;delta++){
      const weekday=todayWeekday+delta;
      if(selected.includes(weekday))onboarding[delta]=sessions[next++];
    }
  }else{
    const rotated=rotateToFirstWorkout(planData.plan);
    for(let i=0;i<onboardingDays;i++)onboarding[i]=rotated[i]||rest();
  }

  let firstWorkoutDelta=0;
  if(selected.length&&!firstWorkoutException){
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
  planData._firstWorkoutExceptionActive=firstWorkoutException;
  planData._onboardingEndsDate=dateOnly(todayLocal+onboardingDays*DAY_MS);
  planData._regularStartedMs=todayLocal+onboardingDays*DAY_MS-offsetMs;
  planData._regularCompletedSequenceCount=Number.isFinite(Number(opts.regularCompletedSequenceCount))?Math.max(0,Math.floor(Number(opts.regularCompletedSequenceCount))):0;
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
  // Calendar decides whether today is a training slot. Completion decides
  // which split unit is due, so skipped days never consume a workout.
  const regular=phase.phase==='regular',current=phase.days&&phase.days[phase.index],count=regular?regularSequenceCount(planData,opts.completedSessions):sequenceCount(planData,opts.completedSessions),pending=nextWorkoutDay(planData,opts.completedSessions,regular);
  const firstException=!regular&&planData&&planData._firstWorkoutExceptionActive===true&&!firstWorkoutCompleted(planData,opts.completedSessions);
  // During the bridge week an unfinished first session remains due tomorrow.
  // From the first full Saturday, the official calendar starts at workout one;
  // selected/rest days decide when, completion order decides what is due.
  if(pending&&(firstException||isTrainingDay(current))){const held=phase.days.slice();held[phase.index]=pending;return Object.assign({},phase,{days:held,sequenceHeld:!isTrainingDay(current)||dayKey(current)!==dayKey(pending),firstWorkoutException:firstException,completedSequenceCount:count});}
  return Object.assign({},phase,{firstWorkoutException:false,completedSequenceCount:count});
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
  planData._schedulePendingStart=Boolean(!phase.firstWorkoutException&&planData._firstWorkoutDate&&planData._firstWorkoutDate>dateOnly(todayLocal));
  const seq=workoutSequence(planData);planData._nextWorkoutIndex=seq.length?phase.completedSequenceCount%seq.length:0;
  if(phase.startDate)planData._scheduleStartDate=phase.startDate;
  return planData;
}
function trainingDayForNow(planData,options){const phase=phaseFor(planData,options),day=phase.days&&phase.days[phase.index];return day?isTrainingDay(day):null;}
module.exports={DAY_MS,isTrainingDay,normalizePreferredDays,saturdayIndexForLocalDay,alignPlan,phaseFor,materializePlan,trainingDayForNow,dayKey,firstWorkoutCompleted,workoutSequence,sequenceCount,regularSequenceCount,nextWorkoutDay,recordCompletion};
