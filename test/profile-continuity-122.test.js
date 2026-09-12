'use strict';
const assert=require('node:assert/strict');
const http=require('node:http'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
process.env.EF_DATA_DIR=fs.mkdtempSync(path.join(os.tmpdir(),'ef-continuity-'));
process.env.PORT='0';
const server=require('../server');
const db=require('../lib/db');
const schedule=require('../lib/workout-schedule');
function req(method,url,body,cookie){return new Promise((resolve,reject)=>{
 const data=body==null?null:JSON.stringify(body);
 const r=http.request({host:'127.0.0.1',port:server.address().port,path:url,method,headers:{...(cookie?{Cookie:cookie}:{}),...(data?{'Content-Type':'application/json','Content-Length':Buffer.byteLength(data)}:{})}},res=>{let text='';res.on('data',d=>text+=d);res.on('end',()=>resolve({status:res.statusCode,data:JSON.parse(text||'{}'),cookie:(res.headers['set-cookie']||[]).join(';').match(/ef_session=[^;]*/)?.[0]}));});r.on('error',reject);r.end(data);
});}
(async()=>{
 await new Promise(r=>server.listening?r():server.once('listening',r));
 const signup=await req('POST','/api/auth/signup',{email:'continuity122@gmail.com',password:'StrongPassword123',name:'Test'});
 assert.equal(signup.status,201);const cookie=signup.cookie;
 const initial={gender:'male',age:30,height:181,weight:108,targetWeight:85,goal:'lose',experience:'advanced',equipment:'gym',trainingDays:4,preferredDays:[0,2,4,6],trainingMinutes:60,dailyActivity:'light',sleep:'ok',stress:'mid',diet:'balanced',mealCount:3,availableFoods:['tmatm','khyar'],injuries:[],weakPoints:[],healthConditions:[],onboardingComplete:true};
 const saved=await req('PUT','/api/mobile/profile',{profile:initial},cookie);assert.equal(saved.status,200);assert.deepEqual(saved.data.profile.preferredDays,[0,2,4,6]);
 const bootstrap=await req('GET','/api/mobile/bootstrap',null,cookie);const id=bootstrap.data.user.id;
 const oldStart=Date.now()-21*86400000;
 const makePlan=()=>({key:'continuity',plan:Array.from({length:4},(_,i)=>({name:'Training '+i,exercises:[{n:'Bench Press',sets:3,reps:'8-12',mu:'chest'}]}))});
 const oldPlan=makePlan();schedule.alignPlan(oldPlan,[0,2,4,6],{nowMs:oldStart,offsetMs:10800000});
 db.saveWorkoutPlan(id,'continuity',JSON.stringify(oldPlan));
 const oldAnchor=oldPlan._scheduleStartedMs;
 const session=db.startWorkoutSession(id,db.activeWorkoutPlan(id).id,'day_0','Training 0');
 const patch=await req('PUT','/api/mobile/profile',{patch:true,profile:{mealCount:4}},cookie);assert.equal(patch.status,200);
 for(const key of ['age','weight','trainingDays','preferredDays','availableFoods','experience','onboardingComplete'])assert.deepEqual(patch.data.profile[key],saved.data.profile[key],key);
 let boot=await req('GET','/api/mobile/bootstrap',null,cookie);
 assert.equal(boot.data.workoutPlan.data._needsProfileRefresh,false,'nutrition-only edit must not regenerate workout');
 const changed=await req('PUT','/api/mobile/profile',{patch:true,profile:{weight:105}},cookie);assert.equal(changed.status,200);
 boot=await req('GET','/api/mobile/bootstrap',null,cookie);assert.equal(boot.data.workoutPlan.data._needsProfileRefresh,true);
 const activation=await req('PUT','/api/mobile/workout-plan',{key:'continuity',plan:makePlan(),selectedDays:[0,2,4,6]},cookie);assert.equal(activation.status,200,JSON.stringify(activation.data));
 const current=JSON.parse(db.activeWorkoutPlan(id).plan_json);assert.equal(current._scheduleStartedMs,oldAnchor,'journey anchor must not reset');
 assert.equal(db.workoutSession(session,id).id,session,'session survives edits');
 boot=await req('GET','/api/mobile/bootstrap',null,cookie);assert.equal(boot.data.workoutPlan.data._needsProfileRefresh,false);
 const invalid=await req('PUT','/api/mobile/profile',{patch:true,profile:{trainingDays:3}},cookie);assert.equal(invalid.status,400);
 assert.equal(JSON.parse(db.mobileProfile(id).profile_json).trainingDays,4);
 console.log('profile-continuity-122: partial edits, preserved fields, meaningful refresh, stable anchor, session retention, validation passed');
})().then(()=>server.close(()=>process.exit(0))).catch(e=>{console.error(e);server.close(()=>process.exit(1));});
