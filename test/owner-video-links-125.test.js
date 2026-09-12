'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),vm=require('node:vm');
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'ef-video-links-'));process.env.EF_DATA_DIR=tmp;
const guard=require('../lib/video-guard'),db=require('../lib/db');
const expected={
 'Cable Crunch':['K2m0jj6RfYg','mKp3sLESlhU','iRYIqSFN21w'],
 'Cable Woodchop':['db4_x6rpji8','yy3TRnJYE08','8OZImYISmSg'],
 "Child's Pose Lower Back":['3uj8eL4hwTo','AgwjXQJqfYo'],
 'Decline Sit-Up':['g6bFHtU-SPo','G2vYhVJq_Nk'],
 'Hanging Leg Raise':['Q-HRZLba_20','2HgbXXA-uqE'],
 'Hanging Leg Raise (Pull-Up Bar)':['Q-HRZLba_20','2HgbXXA-uqE'],
 'Thoracic Rotation (CARs)':['vMuOcANVE1o','4NnQeVkOjM']
};
const bundle=JSON.parse(fs.readFileSync(path.join(__dirname,'../mobile/assets/catalog/exercise_videos.json'),'utf8')).videos;
const src=fs.readFileSync(path.join(__dirname,'../app/workout/engine/db.js'),'utf8');
const ctx=vm.createContext({});new vm.Script(src+'\nthis.dbs=[GYM_DB,HOME_DB,MODULE_DB];').runInContext(ctx);
const all=[];(function walk(v){if(!v||typeof v!=='object')return;if(typeof v.n==='string')all.push(v);Object.values(v).forEach(walk);})(ctx.dbs);
let checks=0;const eq=(a,b,msg)=>{assert.equal(a,b,msg);checks++;};
for(const [name,[id,...old]] of Object.entries(expected)){
 const entries=all.filter(x=>x.n===name);assert(entries.length>0,name);
 for(const x of entries)eq(x.vid,id,'source record '+name);
 eq(guard.catalogueVid(name),id,'server catalogue '+name);
 eq(bundle[guard.videoKey(name)],id,'offline catalogue '+name);
 eq(guard.resolve('',null,name).videoId,id,'missing-link lookup '+name);
 for(const previous of old){eq(guard.resolve(previous,null,name).videoId,id,'known old id '+name);eq(guard.resolve('https://www.youtube.com/watch?v='+previous,null,name).videoId,id,'saved URL '+name);}
 eq(guard.resolve('ezvyKMleqiA',null,name).videoId,'ezvyKMleqiA','unlisted authored id must not be rewritten');
}
eq(bundle['ab wheel rollout'],'tmy1wmws9z4','an alternative exercise must not inherit Cable Crunch video');
const warm=require('../lib/warmup-activation').activationFor(['back']);
eq(warm.find(x=>x.name==='Thoracic Rotation (CARs)').videoId,'vMuOcANVE1o','guided warmup');
const cool=require('../lib/stretch-cooldown').cooldownFor(['back']);
eq(cool.find(x=>x.name==="Child's Pose Lower Back").videoId,'3uj8eL4hwTo','guided cooldown');
// Execute the actual saved-plan enrichment function with scheduling isolated.
const mobile=fs.readFileSync(path.join(__dirname,'../api/mobile.js'),'utf8');
const a=mobile.indexOf('function _enrichPlanVideoIds('),b=mobile.indexOf('// [ONE-CALORIE]',a);assert(a>=0&&b>a);
const apiCtx=vm.createContext({require:n=>{assert.equal(n,'../lib/video-guard');return guard;},workoutSchedule:{materializePlan(){}}});
new vm.Script(mobile.slice(a,b)+'\nthis.enrich=_enrichPlanVideoIds;').runInContext(apiCtx);
const saved={data:{plan:[{exercises:[{n:'Cable Crunch',vid:'mKp3sLESlhU'}],warmActivation:[{name:'Thoracic Rotation (CARs)',videoId:'4NnQeVkOjM'}],stretchCooldown:[{name:"Child's Pose Lower Back",videoId:'AgwjXQJqfYo'}]}]}};
apiCtx.enrich(saved);const day=saved.data.plan[0];
eq(day.exercises[0].videoId,'K2m0jj6RfYg','saved workout');eq(day.warmActivation[0].videoId,'vMuOcANVE1o','saved warmup');eq(day.stretchCooldown[0].videoId,'3uj8eL4hwTo','saved cooldown');
const key=guard.videoKey('Cable Crunch');
db.setVideoOverride(key,'Cable Crunch','ezvyKMleqiA',null,null);guard.invalidateOverrides();
eq(guard.resolve('mKp3sLESlhU',null,'Cable Crunch').videoId,'ezvyKMleqiA','admin override wins');apiCtx.enrich(saved);eq(day.exercises[0].videoSource,'override','saved admin override metadata');
db.setVideoOverride(key,'Cable Crunch','',null,null);guard.invalidateOverrides();apiCtx.enrich(saved);eq(day.exercises[0].videoId,'','admin removal respected');eq(day.exercises[0].videoSource,'removed','saved removal metadata');
db.clearVideoOverride(key);guard.invalidateOverrides();
console.log(checks+' owner video-link checks passed; playback and Flutter execution not tested.');
fs.rmSync(tmp,{recursive:true,force:true});
