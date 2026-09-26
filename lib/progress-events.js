'use strict';
// Rebuildable, account-scoped Progress Story projection over trusted source data.
const { db } = require('./db');
const coach = require('./coach-progression');
const MONTH = /^\d{4}-\d{2}$/;
db.exec(`CREATE TABLE IF NOT EXISTS progress_events (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 user_id INTEGER NOT NULL,
 event_key TEXT NOT NULL,
 event_type TEXT NOT NULL,
 source_type TEXT NOT NULL,
 source_id TEXT NOT NULL,
 occurred_at TEXT NOT NULL,
 period_key TEXT NOT NULL,
 payload_json TEXT NOT NULL,
 seen_at TEXT,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 UNIQUE(user_id,event_key),
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_progress_events_user_period ON progress_events(user_id,period_key,occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_progress_events_user_seen ON progress_events(user_id,seen_at,occurred_at DESC);`);
const q={
 sessions:db.prepare("SELECT id,finished_at,started_at FROM workout_sessions WHERE user_id=? AND status='completed' ORDER BY COALESCE(finished_at,started_at) ASC,id ASC LIMIT ?"),
 sets:db.prepare("SELECT ws.session_id,ws.exercise_key,ws.exercise_name,ws.weight,ws.reps,ws.rir,ws.completed,s.finished_at,s.started_at FROM workout_sets ws JOIN workout_sessions s ON s.id=ws.session_id WHERE s.user_id=? AND s.status='completed' AND ws.completed=1 ORDER BY COALESCE(s.finished_at,s.started_at) ASC,ws.session_id ASC,ws.id ASC LIMIT ?"),
 weights:db.prepare('SELECT day,weight FROM weight_logs WHERE user_id=? ORDER BY day ASC LIMIT ?'),
 nutrition:db.prepare('SELECT day,calories,protein,carbs,fat,water_ml FROM nutrition_days WHERE user_id=? ORDER BY day ASC LIMIT ?'),
 measurements:db.prepare('SELECT day,waist,chest,hips,arm,thigh,body_fat FROM body_measurements WHERE user_id=? ORDER BY day ASC LIMIT ?'),
 profile:db.prepare('SELECT profile_json FROM mobile_profiles WHERE user_id=?'),
 events:db.prepare('SELECT id,user_id,event_key,event_type,source_type,source_id,occurred_at,period_key,payload_json,seen_at FROM progress_events WHERE user_id=? AND period_key=? ORDER BY occurred_at DESC,id DESC LIMIT ?'),
 upsert:db.prepare('INSERT INTO progress_events(user_id,event_key,event_type,source_type,source_id,occurred_at,period_key,payload_json,seen_at,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,NULL,?,?) ON CONFLICT(user_id,event_key) DO UPDATE SET event_type=excluded.event_type,source_type=excluded.source_type,source_id=excluded.source_id,occurred_at=excluded.occurred_at,period_key=excluded.period_key,payload_json=excluded.payload_json,updated_at=excluded.updated_at'),
 deleteSource:db.prepare('DELETE FROM progress_events WHERE user_id=? AND source_type=?'),
 markSeen:db.prepare('UPDATE progress_events SET seen_at=COALESCE(seen_at,?) WHERE user_id=? AND id=?'),
};
function parse(v,f){try{return JSON.parse(v)}catch(_){return f}}
function now(){return new Date().toISOString()}
function cairoMonth(v=new Date()){const d=v instanceof Date?v:new Date(v);if(!Number.isFinite(d.getTime()))return cairoMonth();return new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit'}).format(d)}
function period(v){const s=String(v||'');if(/^\d{4}-\d{2}-\d{2}$/.test(s))return s.slice(0,7);return cairoMonth(v)}
function round(v){return Math.round((Number(v)||0)*10)/10}
function iso(v){const d=new Date(v||0);return Number.isFinite(d.getTime())?d.toISOString():now()}
function sources(id){return {sessions:q.sessions.all(id,2000),sets:q.sets.all(id,20000),weights:q.weights.all(id,2000),nutrition:q.nutrition.all(id,1000),measurements:q.measurements.all(id,2000)}}
function profile(id){const r=q.profile.get(id);return r?parse(r.profile_json,{}):{}}
function make(key,type,sourceType,sourceId,at,payload){return {key,type,sourceType,sourceId:String(sourceId),at:iso(at),period:period(at),payload}}
function weightEvents(out,rows,p){const base=rows.length?Number(rows[0].weight):0,target=Number(p.targetWeight||p.target||0);if(!(base>0&&target>0)||Math.abs(target-base)<1)return;const dir=target<base?-1:1,dist=Math.abs(target-base),thresholds=[];for(let kg=5;kg<dist;kg+=5)thresholds.push({key:'distance-'+kg,value:base+dir*kg,kg});thresholds.push({key:'target',value:target,kg:round(dist),target:true});for(const t of thresholds){const hit=rows.find(r=>dir<0?Number(r.weight)<=t.value:Number(r.weight)>=t.value);if(hit)out.push(make('weight-milestone:'+t.key,'weight_milestone','weight_log',hit.day,hit.day,{baseline:round(base),target:round(target),reached:round(hit.weight),changeKg:round(Math.abs(Number(hit.weight)-base)),targetReached:!!t.target}))}}
function workoutEvents(out,sessions,sets){const by=new Map();for(const r of sets){const w=Number(r.weight)||0, reps=Number(r.reps)||0,key=String(r.exercise_key||r.exercise_name||'').trim();if(!(w>0&&reps>0&&key))continue;const id=Number(r.session_id),g=by.get(id)||new Map(),e=Number(coach.e1rm(w,reps))||0,old=g.get(key);if(!old||e>old.e1rm)g.set(key,{key,name:String(r.exercise_name||key),weight:w,reps,rir:r.rir,e1rm:e,at:r.finished_at||r.started_at});by.set(id,g)}const best=new Map();let count=0;for(const s of sessions){count++;for(const l of (by.get(Number(s.id))||new Map()).values()){const old=best.get(l.key)||0;if(l.e1rm>old+.01)out.push(make('new-pr:'+s.id+':'+l.key,'new_pr','workout_session',s.id,s.finished_at||s.started_at,{sessionId:Number(s.id),exerciseKey:l.key,exerciseName:l.name,weight:round(l.weight),reps:l.reps,e1rm:round(l.e1rm),previousE1rm:old?round(old):null}));if(l.e1rm>old)best.set(l.key,l.e1rm)}if(count>=5&&count%5===0)out.push(make('training-consistency:'+count,'training_consistency','workout_sessions','completed-'+count,s.finished_at||s.started_at,{completedSessions:count,milestone:count}))}}
function nutritionEvents(out,rows,p){const target=Number(p.targetCals||p.targetCalories||p.dailyCalories||0);if(!(target>0))return;const by=new Map();for(const r of rows){if(Number(r.calories)<=0)continue;const m=period(r.day),a=by.get(m)||[];a.push(r);by.set(m,a)}for(const [m,a] of by){if(a.length<14)continue;const acc=a.reduce((s,r)=>s+Math.max(0,1-Math.abs(Number(r.calories)-target)/target),0)/a.length*100,rate=Math.min(100,Math.round(a.length/30*100));if(rate<80||acc<85)continue;const last=a[a.length-1];out.push(make('adherence-milestone:'+m,'adherence_milestone','nutrition_days',m,last.day,{month:m,loggedDays:a.length,loggingRate:rate,calorieAccuracy:Math.round(acc),targetCals:Math.round(target)}))}}
function syncUser(userId){const id=Number(userId);if(!Number.isInteger(id)||id<=0)return[];const s=sources(id),out=[];workoutEvents(out,s.sessions,s.sets);weightEvents(out,s.weights,profile(id));nutritionEvents(out,s.nutrition,profile(id));const t=now();db.exec('BEGIN');try{for(const type of ['workout_session','workout_sessions','weight_log','nutrition_days'])q.deleteSource.run(id,type);for(const e of out)q.upsert.run(id,e.key,e.type,e.sourceType,e.sourceId,e.at,e.period,JSON.stringify(e.payload),t,t);db.exec('COMMIT')}catch(e){try{db.exec('ROLLBACK')}catch(_){}throw e}return out}
function decode(r){return {id:r.id,eventKey:r.event_key,type:r.event_type,sourceType:r.source_type,sourceId:r.source_id,occurredAt:r.occurred_at,period:r.period_key,seenAt:r.seen_at||null,payload:parse(r.payload_json,{})}}
function story(userId,month){
 const id=Number(userId),current=cairoMonth(),m=MONTH.test(String(month||''))?month:current;
 syncUser(id);
 const ev=q.events.all(id,m,100).map(decode),s=sources(id),p=profile(id);
 const weights=s.weights.filter(r=>period(r.day)===m),sessions=s.sessions.filter(r=>period(r.finished_at||r.started_at)===m),sets=s.sets.filter(r=>period(r.finished_at||r.started_at)===m),nutrition=s.nutrition.filter(r=>period(r.day)===m),measurements=s.measurements.filter(r=>period(r.day)===m),byType={};
 for(const e of ev)byType[e.type]=(byType[e.type]||0)+1;
 const target=Number(p.targetCals||p.targetCalories||p.dailyCalories||0),withCalories=nutrition.filter(r=>Number(r.calories)>0),waterGoal=Math.max(1,Number(p.waterGoalMl||p.waterGoal||2500)||2500),withWater=nutrition.filter(r=>Number(r.water_ml)>0);
 const accuracy=target>0&&withCalories.length?Math.round(withCalories.reduce((n,r)=>n+Math.max(0,1-Math.abs(Number(r.calories)-target)/target),0)/withCalories.length*100):null;
 const months=new Set();
 for(const r of s.weights)months.add(period(r.day));
 for(const r of s.measurements)months.add(period(r.day));
 for(const r of s.nutrition)if(Number(r.calories)>0||Number(r.water_ml)>0)months.add(period(r.day));
 for(const r of s.sessions)months.add(period(r.finished_at||r.started_at));
 months.add(m);
 const availableMonths=[...months].filter(x=>MONTH.test(x)).sort().reverse().slice(0,24);
 const measurementStart=measurements.length?measurements[0]:null,measurementEnd=measurements.length?measurements[measurements.length-1]:null;
 return {month:m,closed:m<current,availableMonths,empty:!ev.length&&!weights.length&&!sessions.length&&!nutrition.length&&!measurements.length,summary:{
  sessions:sessions.length,sets:sets.length,totalVolume:round(sets.reduce((n,r)=>n+(Number(r.weight)||0)*(Number(r.reps)||0),0)),
  weightStart:weights.length?Number(weights[0].weight):null,weightEnd:weights.length?Number(weights[weights.length-1].weight):null,weightChange:weights.length>1?round(Number(weights[weights.length-1].weight)-Number(weights[0].weight)):null,
  measurementDays:measurements.length,measurementStart,measurementEnd,
  nutritionLoggedDays:withCalories.length,avgCalories:withCalories.length?Math.round(withCalories.reduce((n,r)=>n+Number(r.calories),0)/withCalories.length):null,calorieTarget:target>0?Math.round(target):null,calorieAccuracy:accuracy,calorieTargetDays:target>0?withCalories.filter(r=>Math.abs(Number(r.calories)-target)/target<=.1).length:0,
  waterLoggedDays:withWater.length,waterGoalDays:withWater.filter(r=>Number(r.water_ml)>=waterGoal).length,waterGoalMl:Math.round(waterGoal),eventCount:ev.length,byType
 },events:ev,moments:ev.filter(e=>!e.seenAt).slice(0,5)};
}
function markSeen(userId,ids){const id=Number(userId),list=Array.isArray(ids)?ids.map(Number).filter(Number.isInteger).slice(0,20):[],at=now();for(const eventId of list)q.markSeen.run(at,id,eventId);return {acknowledged:list.length}}
module.exports={syncUser,story,markSeen};
