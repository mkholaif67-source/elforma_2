'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),http=require('node:http'),vm=require('node:vm');
process.env.EF_DATA_DIR=fs.mkdtempSync(path.join(os.tmpdir(),'ef-review125-'));
process.env.PORT='0';
const server=require('../server'),db=require('../lib/db');
const bridge=require('../lib/mobile-nutrition-bridge'),host=require('../lib/nutrition-engine-host');
function req(method,url,body,cookie){return new Promise((resolve,reject)=>{
 const data=body==null?null:JSON.stringify(body);
 const r=http.request({host:'127.0.0.1',port:server.address().port,path:url,method,headers:{...(cookie?{Cookie:cookie}:{}),...(data?{'Content-Type':'application/json','Content-Length':Buffer.byteLength(data)}:{})}},res=>{let text='';res.on('data',d=>text+=d);res.on('end',()=>resolve({status:res.statusCode,data:JSON.parse(text||'{}'),cookie:(res.headers['set-cookie']||[]).join(';').match(/ef_session=[^;]*/)?.[0]}));});r.on('error',reject);r.end(data);
});}
const initial={gender:'male',age:30,height:180,weight:108,targetWeight:85,goal:'lose',experience:'intermediate',equipment:'gym',trains:true,trainingDays:4,preferredDays:[],trainingMinutes:60,dailyActivity:'light',sleep:'good',stress:'mid',diet:'balanced',mealCount:2,injuries:[],weakPoints:[],healthConditions:[],onboardingComplete:true,weeklyRate:.75,waist:null,neck:null,hips:null,bodyFat:null};
(async()=>{
 await new Promise(r=>server.listening?r():server.once('listening',r));
 const a=await req('POST','/api/auth/signup',{email:'root125a@gmail.com',password:'StrongPassword123',name:'User A'}),b=await req('POST','/api/auth/signup',{email:'root125b@gmail.com',password:'StrongPassword123',name:'User B'});
 assert.equal(a.status,201);assert.equal(b.status,201);
 const saved=await req('PUT','/api/mobile/profile',{profile:initial,preparePlans:true},a.cookie);
 assert.equal(saved.status,200,JSON.stringify(saved.data));assert(saved.data.readiness.workoutReady);assert(saved.data.readiness.nutritionReady);
 for(const key of ['waist','neck','hips','bodyFat'])assert.equal(saved.data.profile[key],null);
 const ba=await req('GET','/api/mobile/bootstrap',null,a.cookie),bb=await req('GET','/api/mobile/bootstrap',null,b.cookie);
 assert(ba.data.workoutPlan.data._locked);assert(ba.data.workoutPlan.data.previewDay.exercises.length);assert.equal(ba.data.workoutPlan.data.plan,undefined);assert.equal(bb.data.profile,null);assert.equal(bb.data.workoutPlan,null);
 const aid=ba.data.user.id,bid=bb.data.user.id,planid=ba.data.workoutPlan.id;
 assert(db.db.prepare('SELECT plan_json FROM prepared_nutrition_plans WHERE user_id=?').get(aid));assert(!db.db.prepare('SELECT plan_json FROM prepared_nutrition_plans WHERE user_id=?').get(bid));
 // A repeat is idempotent for training and does not reset journey anchor.
 const stored=JSON.parse(db.activeWorkoutPlan(aid).plan_json);assert(stored.plan.some(d=>d.exercises?.length));
 const anchor=stored._scheduleStartedMs;
 const repeated=await req('PUT','/api/mobile/profile',{profile:initial,preparePlans:true},a.cookie);assert.equal(repeated.status,200);
 const repeatBoot=await req('GET','/api/mobile/bootstrap',null,a.cookie);assert.equal(repeatBoot.data.workoutPlan.id,planid);assert.equal(JSON.parse(db.activeWorkoutPlan(aid).plan_json)._scheduleStartedMs,anchor);
 // Exact-context snapshot survives an unavailable generator on first read.
 const original=host.computeMealPlan;host.computeMealPlan=()=>{throw Error('simulated_engine_outage');};
 const resumed=await req('GET','/api/mobile/nutrition-plan',null,a.cookie);host.computeMealPlan=original;
 assert.equal(resumed.status,200,JSON.stringify(resumed.data));assert(resumed.data.plan.meals.length);
 assert.equal(resumed.data.plan.meals.length,1,'free preview must not expose the full saved plan');
 const patch=await req('PUT','/api/mobile/profile',{patch:true,profile:{mealCount:3}},a.cookie);assert.equal(patch.status,200);
 for(const key of ['waist','neck','hips','bodyFat'])assert.equal(patch.data.profile[key],null,'patch must not invent '+key);
 const nutrition=await req('GET','/api/mobile/nutrition-plan?plan=0',null,a.cookie);
 assert.equal(nutrition.status,200,JSON.stringify(nutrition.data));assert.equal(nutrition.data.targets.targetCals,patch.data.profile.targetCals);
 const wp=await req('POST','/api/workout/compute',{profile:{...initial,goal:'cut',exp:'intermediate',equip:'gym',days:4,time:60,daily:'light'}},a.cookie);
 assert.equal(wp.status,200);assert.equal(wp.data.metrics.targetCals,patch.data.profile.targetCals);
 assert.equal(ba.data.workoutPlan.data._metrics.recoveryScore,87);
 // Exact screenshot reproducer: fake 3% -> 2859 / 286 / 258 / 76.
 const bad=bridge.buildEngineContext(initial,{bodyFat:3,weeklyRate:.75});
 const old=host.computeTargets(bad.profile,bad.inputs);assert.equal(old.targetCals,2859);assert.equal(old.macros.protein,286);
 const good=bridge.buildEngineContext(initial,{});assert.equal(host.computeTargets(good.profile,good.inputs).targetCals,2369);
 assert.equal(bridge.navyBodyFat('male',180,95,40),22);
 // Quarantine only the known legacy quartet; never erase a genuine 40cm value alone.
 const repair=require('../lib/profile-integrity').repairLegacyMeasurements;
 assert.equal(repair({...initial,waist:40,neck:20,hips:50,bodyFat:3}).bodyFat,null);
 assert.equal(repair({...initial,waist:40}).waist,40);
 assert.equal(repair({...initial,waist:40,neck:20,hips:50,bodyFat:3,measurementSchemaVersion:2}).bodyFat,3);
 // Stored recovery stays exactly in sync with the engine for diverse inputs.
 const code=fs.readFileSync(path.join(__dirname,'../app/workout/engine/analysis.js'),'utf8');
 for(const age of [30,45,60,70])for(const sleep of ['poor','ok','good']){
   const p={...initial,age,sleep},ctx={state:{...p,days:p.trainingDays,daily:p.dailyActivity}};vm.createContext(ctx);vm.runInContext(code,ctx);
   assert.equal(require('../lib/workout-recovery').score(p),vm.runInContext('calcRecovery()',ctx));
 }
 // Classified favorites are per-account and do not modify profile timestamps.
 const profileStamp=db.mobileProfile(aid).updated_at;
 const preference=await req('PUT','/api/mobile/food-preference',{foodId:'jbn_rwds',mealSlot:'breakfast',favorite:true},a.cookie);
 assert.equal(preference.status,200);assert.equal(db.mobileProfile(aid).updated_at,profileStamp);
 const fa=await req('GET','/api/mobile/food-preferences',null,a.cookie),fb=await req('GET','/api/mobile/food-preferences',null,b.cookie);
 assert(fa.data.mealFavorites.breakfast.some(f=>f.id==='jbn_rwds'));assert.deepEqual(fb.data.mealFavorites.breakfast,[]);
 assert.equal((await req('PUT','/api/mobile/food-preference',{foodId:'not-a-food',mealSlot:'main',favorite:true},a.cookie)).status,400);
 // Actual long-poll delivery: no bootstrap/calorie calculation needed to remove ad.
 require('../lib/settings').setJSON('announcements',[{id:'remove-me',active:true,title:'Test',placement:'both',audience:'all'}]);
 const first=await req('GET','/api/mobile/announcements/watch',null,a.cookie);assert.equal(first.status,200);
 const started=Date.now();const waiting=req('GET','/api/mobile/announcements/watch?cursor='+first.data.cursor,null,a.cookie);
 setTimeout(()=>{require('../lib/settings').setJSON('announcements',[]);require('../lib/announcement-events').changed();},40);
 const update=await waiting;assert.equal(update.status,200);assert(Date.now()-started<2000);assert.deepEqual(update.data.announcements,[]);
 console.log('PASS: null measurements, exact calorie reproduction, parity, prepared plans, idempotency, server account isolation, recovery parity, live announcements');
})().then(()=>server.close(()=>process.exit(0))).catch(e=>{console.error(e);server.close(()=>process.exit(1));});
