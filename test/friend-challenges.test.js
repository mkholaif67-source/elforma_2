'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
process.env.EF_DATA_DIR=fs.mkdtempSync(path.join(os.tmpdir(),'ef-friends-'));
process.env.EF_DATABASE_ENGINE='sqlite';
const database=require('../lib/db');
const domain=require('../lib/friend-challenges');
const community=require('../lib/community');
const sql=database.db,created=new Date().toISOString();
for(const [id,name] of [[1,'علي'],[2,'محمد'],[3,'عمر'],[4,'سارة']])sql.prepare('INSERT INTO users(id,email,name,pass_hash,pass_salt,verified,created_at) VALUES(?,?,?,?,?,?,?)').run(id,`friend${id}@test.local`,name,'x','y',1,created);
const start=new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const end=new Date(Date.parse(start)+6*86400000).toISOString().slice(0,10);
let checks=0;function test(name,fn){fn();checks++;console.log('PASS',name);}
let challenge,code;
test('private challenge is created without changing personal challenges',()=>{
  const personal=community.saveChallenge({title:'تحدي شخصي',start,duration:7,weekdays:[0,1,2,3,4,5,6],offsetMinutes:180},1);
  challenge=domain.create(1,{sourcePersonalId:personal.id,title:'تحدي الاصحاب',kind:'habit',metric:'manual_daily',scoring:'daily',start,end,weekdays:[0,1,2,3,4,5,6],sharing:{workoutSummary:true},maxMembers:5});
  assert.equal(challenge.role,'owner');assert.equal(community.detail(personal.id,1).title,'تحدي شخصي');assert.equal(domain.list(2).length,0);
});
test('active member can invite and owner approval is required',()=>{
  const invite=domain.createInvite(challenge.id,1,{validDays:7,maxUses:4});code=invite.code;
  const preview=domain.preview(code,2);assert.equal(preview.title,'تحدي الاصحاب');assert.match(preview.privacyText,/ملخص التمرين/);
  const request=domain.requestJoin(code,2,'محمد');assert.equal(request.status,'pending');assert.equal(domain.list(2).length,0);
  assert.equal(domain.detail(challenge.id,1).pendingCount,1);
  domain.decide(challenge.id,1,2,true);assert.equal(domain.list(2).length,1);
});
test('joined friend can invite a third friend but owner still accepts',()=>{
  const invite=domain.createInvite(challenge.id,2,{validDays:3,maxUses:2});
  domain.requestJoin(invite.code,3,'عمر');
  const owner=domain.detail(challenge.id,1);assert.equal(owner.requests[0].invitedBy,'محمد');
  assert.throws(()=>domain.decide(challenge.id,2,3,true),/غير مسموح/);
  domain.decide(challenge.id,1,3,true);assert.equal(domain.detail(challenge.id,1).participantCount,3);
});
test('daily entries are idempotent and leaderboard exposes summaries only',()=>{
  domain.logEntry(challenge.id,2,true,'تم');domain.logEntry(challenge.id,2,true,'تم مرة واحدة');domain.logEntry(challenge.id,3,false,'');
  const board=domain.detail(challenge.id,1).leaderboard;assert.equal(board[0].displayName,'محمد');assert.equal(board[0].score,1);assert.equal(board[0].email,undefined);assert.equal(board[0].userId,undefined);
});
test('automatic workout and nutrition scores use existing app data',()=>{
  const weekday=new Date(start+'T12:00:00Z').getUTCDay();
  const workout=domain.create(1,{title:'اعلى سكوات',kind:'workout',metric:'workout_max',scoring:'highest',exerciseKey:'Squat',target:150,unit:'كجم',start,end,weekdays:[weekday]});
  sql.prepare("INSERT INTO workout_sessions(id,user_id,plan_id,day_key,day_name,status,started_at,finished_at,duration_sec) VALUES(?,?,?,?,?,'completed',?,?,?)").run(501,1,null,'day-1','تمرين الرجل',start+'T10:00:00Z',start+'T11:00:00Z',3600);
  sql.prepare("INSERT INTO workout_sets(session_id,exercise_key,exercise_name,set_number,weight,reps,completed,logged_at) VALUES(?,?,?,?,?,?,1,?)").run(501,'squat-key','Squat',1,120,5,start+'T10:30:00Z');
  assert.equal(domain.detail(workout.id,1).mine.score,120);
  database.saveNutritionDay(1,start,{calories:2000,protein:150,carbs:200,fat:60,waterMl:2500,meals:[]});
  const nutrition=domain.create(1,{title:'التزام السعرات',kind:'nutrition',metric:'nutrition_days',scoring:'daily',target:2000,unit:'سعر',start,end,weekdays:[weekday]});
  const water=domain.create(1,{title:'هدف المياه',kind:'water',metric:'water_days',scoring:'daily',target:2000,unit:'مل',start,end,weekdays:[weekday]});
  assert.equal(domain.detail(nutrition.id,1).mine.score,1);assert.equal(domain.detail(water.id,1).mine.score,1);
});
test('owner can reject remove and close while member can leave',()=>{
  const invite=domain.createInvite(challenge.id,2,{maxUses:1});domain.requestJoin(invite.code,4,'سارة');domain.decide(challenge.id,1,4,false);assert.equal(domain.detail(challenge.id,1).pendingCount,0);
  domain.removeMember(challenge.id,1,3);assert.equal(domain.detail(challenge.id,1).participantCount,2);
  assert.throws(()=>domain.leave(challenge.id,1),/صاحب التحدي/);domain.leave(challenge.id,2);assert.equal(domain.detail(challenge.id,1).participantCount,1);
  const closed=domain.close(challenge.id,1);assert.equal(closed.status,'closed');assert.equal(closed.finalResults.length,1);assert.throws(()=>domain.createInvite(challenge.id,1),/انتهى/);
});
test('schema migration is recorded and account export data is isolated',()=>{
  const migration=sql.prepare('SELECT version,name FROM schema_migrations ORDER BY version DESC LIMIT 1').get();assert.equal(migration.version,2026092401);const exported=domain.exportUser(1);assert.equal(exported.owned.length,4);assert(exported.memberships.every(x=>x.user_id===1));
});
console.log(`${checks} friend challenge domain checks passed`);
sql.close();fs.rmSync(process.env.EF_DATA_DIR,{recursive:true,force:true});
