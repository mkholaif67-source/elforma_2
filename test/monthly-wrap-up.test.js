'use strict';
const assert=require('node:assert/strict'),http=require('node:http'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
process.env.EF_DATA_DIR=fs.mkdtempSync(path.join(os.tmpdir(),'ef-monthly-wrap-'));process.env.PORT='0';
const server=require('../server'),db=require('../lib/db'),progress=require('../lib/progress-events');
function request(method,pathname,body){return new Promise((resolve,reject)=>{const a=server.address(),raw=body==null?null:JSON.stringify(body),headers={};if(raw){headers['Content-Type']='application/json';headers['Content-Length']=Buffer.byteLength(raw)}const req=http.request({host:'127.0.0.1',port:a.port,method,path:pathname,headers},res=>{let text='';res.on('data',c=>text+=c);res.on('end',()=>{let json={};try{json=JSON.parse(text||'{}')}catch(_){}resolve({status:res.statusCode,json})})});req.on('error',reject);if(raw)req.write(raw);req.end()})}
function previousMonth(){const now=new Date(),d=new Date(now.getFullYear(),now.getMonth()-1,1);return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`}
(async()=>{
 await new Promise(r=>server.listening?r():server.on('listening',r));
 const signup=await request('POST','/api/auth/signup',{email:`monthly_${Date.now()}@gmail.com`,password:'supersecret123',name:'Monthly Story'});
 assert.equal(signup.status,201);
 const uid=signup.json.user.id,month=previousMonth();
 db.saveMobileProfile(uid,JSON.stringify({weight:92,targetWeight:82,targetCals:2000,waterGoalMl:2500}));
 db.saveWeight(uid,`${month}-02`,92,null);db.saveWeight(uid,`${month}-25`,89.5,null);
 db.saveMeasurement(uid,`${month}-03`,{waist:100,chest:105,hips:null,arm:null,thigh:null,bodyFat:null});db.saveMeasurement(uid,`${month}-24`,{waist:96,chest:106,hips:null,arm:null,thigh:null,bodyFat:null});
 db.saveNutritionDay(uid,`${month}-04`,{calories:1950,protein:150,carbs:190,fat:60,waterMl:2600,meals:[]});
 db.saveNutritionDay(uid,`${month}-05`,{calories:2050,protein:155,carbs:200,fat:62,waterMl:2400,meals:[]});
 const recap=progress.story(uid,month);
 assert.equal(recap.closed,true);assert.equal(recap.empty,false);assert(recap.availableMonths.includes(month));
 assert.equal(recap.summary.weightStart,92);assert.equal(recap.summary.weightEnd,89.5);assert.equal(recap.summary.weightChange,-2.5);
 assert.equal(recap.summary.measurementDays,2);assert.equal(recap.summary.nutritionLoggedDays,2);assert.equal(recap.summary.calorieAccuracy,98);assert.equal(recap.summary.calorieTargetDays,2);assert.equal(recap.summary.waterGoalDays,1);
 const current=progress.story(uid);assert(current.availableMonths.includes(month));
 const shell=fs.readFileSync(path.join(__dirname,'../mobile/lib/screens/shell_screen.dart'),'utf8');
 const card=fs.readFileSync(path.join(__dirname,'../mobile/lib/widgets/monthly_wrap_up_card.dart'),'utf8');
 const screen=fs.readFileSync(path.join(__dirname,'../mobile/lib/screens/progress_screen.dart'),'utf8');
 assert(shell.includes("seen_monthly_wrap_up:$accountId:$month"));assert(shell.includes('progressStory(month: month)'));assert(shell.includes('await showMonthlyWrapUp'));
 assert(card.includes('PageView('));assert(card.includes('جاهز للشهر الجديد'));assert(card.includes('اسحب يمين وشمال'));
 assert(screen.includes('_monthPicker()'));assert(screen.includes('افتح كارد حصاد الشهر'));
 console.log('Monthly recap persistence, totals, one-time startup card and archive access passed');
 server.close(()=>process.exit(0));
})().catch(e=>{console.error(e);server.close(()=>process.exit(1))});
