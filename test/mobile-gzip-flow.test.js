'use strict';
// Exercise the actual HTTP wire format. Decode gzip exactly ONCE, as mobile clients do.
const assert=require('node:assert/strict'),http=require('node:http'),zlib=require('node:zlib'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
process.env.EF_DATA_DIR=fs.mkdtempSync(path.join(os.tmpdir(),'ef-gzip-flow-'));
process.env.PORT='0';
const server=require('../server');
const commerce=require('../lib/commerce');
function request(method,url,body,cookie,encoding='gzip'){
 return new Promise((resolve,reject)=>{
  const payload=body==null?null:JSON.stringify(body);
  const headers={'Accept-Encoding':encoding,'X-Tz-Offset':'180',...(cookie?{Cookie:cookie}:{}),...(payload?{'Content-Type':'application/json','Content-Length':Buffer.byteLength(payload)}:{})};
  const req=http.request({host:'127.0.0.1',port:server.address().port,method,path:url,headers},res=>{
   const chunks=[];res.on('data',c=>chunks.push(c));res.on('error',reject);res.on('end',()=>{
    try {
     const raw=Buffer.concat(chunks);
     const decoded=res.headers['content-encoding']==='gzip'?zlib.gunzipSync(raw):raw;
     assert(!(decoded[0]===31&&decoded[1]===139),'DOUBLE GZIP: '+url);
     const data=JSON.parse(decoded.toString('utf8'));
     resolve({status:res.statusCode,data,wireBytes:raw.length,decodedBytes:decoded.length,encoding:res.headers['content-encoding'],cookie:(res.headers['set-cookie']||[]).join(';').match(/ef_session=[^;]*/)?.[0]});
    }catch(e){reject(e);}
   });
  });
  req.setTimeout(45000,()=>req.destroy(new Error('HTTP test timed out: '+url)));
  req.on('error',reject);req.end(payload);
 });
}
(async()=>{
 await new Promise(r=>server.listening?r():server.once('listening',r));
 const signup=await request('POST','/api/auth/signup',{email:'gzipflow123@gmail.com',password:'StrongPassword123',name:'Gzip test'});
 assert.equal(signup.status,201);const cookie=signup.cookie;
 const before=await request('GET','/api/mobile/bootstrap',null,cookie);assert.equal(before.status,200);assert.equal(before.data.profile,null);assert.equal(before.data.workoutPlan,null);
 const missing=await request('GET','/api/mobile/nutrition-plan',null,cookie);assert.equal(missing.status,400);assert.equal(missing.data.error,'profile_required');
 const p={gender:'male',age:30,height:181,weight:108,targetWeight:85,goal:'lose',experience:'advanced',equipment:'gym',trainingDays:4,trainingMinutes:60,dailyActivity:'light',sleep:'ok',stress:'mid',diet:'balanced',mealCount:3,injuries:[],weakPoints:[],healthConditions:[],preferredDays:[],onboardingComplete:true};
 const saved=await request('PUT','/api/mobile/profile',{profile:p},cookie);assert.equal(saved.status,200);
 commerce.adminSetSubscription(before.data.user.id,'pro','active',1,'test');
 const computed=await request('POST','/api/workout/compute',{profile:{gender:'male',age:30,height:181,weight:108,goal:'cut',exp:'advanced',equip:'gym',days:4,time:60,daily:'light',sleep:'ok',stress:'mid',injuries:[],weak:[]}},cookie);
 assert.equal(computed.status,200);assert.equal(computed.encoding,'gzip');assert(computed.data.plans.length>0);
 const chosen=computed.data.plans.find(p=>p.rec)||computed.data.plans[0];
 const activated=await request('PUT','/api/mobile/workout-plan',{key:chosen.key,plan:chosen,selectedDays:[]},cookie);assert.equal(activated.status,200);
 const boot=await request('GET','/api/mobile/bootstrap',null,cookie);assert.equal(boot.status,200);assert(boot.data.workoutPlan.data.plan.length>0);
 const meals=await request('GET','/api/mobile/nutrition-plan',null,cookie);assert.equal(meals.status,200);assert(meals.data.plan.meals.length>0);assert.equal(meals.encoding,'gzip');
 const plain=await request('GET','/api/mobile/nutrition-plan',null,cookie,'identity');assert.deepEqual(plain.data,meals.data);assert.equal(plain.encoding,undefined);
 const forbidden=await request('GET','/api/mobile/nutrition-plan',null,cookie,'gzip;q=0');assert.equal(forbidden.encoding,undefined);assert.deepEqual(forbidden.data,meals.data);
 for(let i=0;i<2;i++){const repeat=await request('GET','/api/mobile/bootstrap',null,cookie);assert(repeat.data.workoutPlan.data.plan.length>0);}
 console.log(JSON.stringify({result:'PASS',newAccount:'profile=null; ready for setup',workoutDays:chosen.plan.filter(d=>d.exercises?.length).length,meals:meals.data.plan.meals.length,workoutWireBytes:computed.wireBytes,workoutDecodedBytes:computed.decodedBytes,nutritionWireBytes:meals.wireBytes,nutritionDecodedBytes:meals.decodedBytes}));
})().then(()=>server.close(()=>process.exit(0))).catch(e=>{console.error(e);server.close(()=>process.exit(1));});
