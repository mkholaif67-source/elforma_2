'use strict';

const { randomUUID, randomBytes, createHash } = require('node:crypto');
const { db } = require('./db');
const DAY = 86400000;
const TYPES = new Set(['workout','nutrition','water','steps','sleep','mood','habit','custom']);
const METRICS = new Set(['manual_daily','manual_value','workout_days','workout_max','nutrition_days','water_days']);
const SCORING = new Set(['daily','sum','highest']);
const fail = (message,status=400) => { const error=new Error(message); error.status=status; throw error; };
const text = (value,max=120) => String(value??'').trim().slice(0,max);
const nowIso = () => new Date().toISOString();
function date(value){const s=text(value,10),d=new Date(s+'T00:00:00Z');if(!/^\d{4}-\d{2}-\d{2}$/.test(s)||!Number.isFinite(+d)||d.toISOString().slice(0,10)!==s)fail('اختار تاريخ صحيح');return s;}
function daysBetween(a,b){return Math.floor((Date.parse(b)-Date.parse(a))/DAY);}
function cairoDay(value=new Date()){const d=value instanceof Date?value:new Date(value);return new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(d);}
function today(now=new Date()){return cairoDay(now);}
function number(value,min,max,required=false){if(value==null||value===''){if(required)fail('اكتب الهدف');return null;}const n=Number(value);if(!Number.isFinite(n)||n<min||n>max)fail('اكتب قيمة صحيحة');return n;}
function parseJson(value,fallback){try{return JSON.parse(value);}catch(_){return fallback;}}
function uniqueWeekdays(value){const list=Array.isArray(value)?[...new Set(value.map(Number))].sort():[0,1,2,3,4,5,6];if(!list.length||list.some(x=>!Number.isInteger(x)||x<0||x>6))fail('اختار يوم واحد على الاقل');return list;}
function shareRules(value){const raw=value&&typeof value==='object'&&!Array.isArray(value)?value:{};return {score:true,progress:true,workoutSummary:raw.workoutSummary===true,nutritionSummary:raw.nutritionSummary===true,personalDetails:false};}
function scheduled(challenge,day){if(day<challenge.start_date||day>challenge.end_date)return false;const weekday=new Date(day+'T12:00:00Z').getUTCDay();return parseJson(challenge.weekdays_json,[]).includes(weekday);}
function scheduledCount(challenge,until){const stop=until<challenge.end_date?until:challenge.end_date;if(stop<challenge.start_date)return 0;let count=0;for(let cursor=Date.parse(challenge.start_date),end=Date.parse(stop);cursor<=end;cursor+=DAY){const d=new Date(cursor).toISOString().slice(0,10);if(scheduled(challenge,d))count++;}return count;}
function row(id){return db.prepare('SELECT * FROM friend_challenges WHERE id=?').get(text(id,80));}
function member(id,userId){return db.prepare('SELECT * FROM friend_challenge_members WHERE challenge_id=? AND user_id=?').get(id,userId);}
function activeMember(id,userId){const value=member(id,userId);if(!value||value.status!=='active')fail('التحدي غير متاح',403);return value;}
function visible(id,userId){const challenge=row(id);if(!challenge)fail('التحدي غير موجود',404);const membership=member(id,userId);if(challenge.owner_id!==userId&&(!membership||!['active'].includes(membership.status)))fail('التحدي غير متاح',403);return {challenge,membership};}
function publicChallenge(challenge){return {id:challenge.id,title:challenge.title,description:challenge.description,kind:challenge.kind,metric:challenge.metric,target:challenge.target,unit:challenge.unit,scoring:challenge.scoring,start:challenge.start_date,end:challenge.end_date,weekdays:parseJson(challenge.weekdays_json,[]),sharing:parseJson(challenge.share_json,{}),status:effectiveStatus(challenge),maxMembers:challenge.max_members,sourcePersonalId:challenge.source_personal_id||null};}
function effectiveStatus(challenge){if(challenge.status!=='active')return challenge.status;return today()>challenge.end_date?'ended':'active';}
function normalizeInput(body,base={}){
 const kind=TYPES.has(body.kind)?body.kind:(TYPES.has(base.kind)?base.kind:'custom');
 const metric=METRICS.has(body.metric)?body.metric:(METRICS.has(base.metric)?base.metric:'manual_daily');
 const scoring=SCORING.has(body.scoring)?body.scoring:(SCORING.has(base.scoring)?base.scoring:(metric==='workout_max'?'highest':metric==='manual_value'?'sum':'daily'));
 const allowed={workout:['manual_daily','manual_value','workout_days','workout_max'],nutrition:['manual_daily','manual_value','nutrition_days'],water:['manual_daily','manual_value','water_days'],steps:['manual_daily','manual_value'],sleep:['manual_daily','manual_value'],mood:['manual_daily','manual_value'],habit:['manual_daily','manual_value'],custom:['manual_daily','manual_value']};if(!allowed[kind].includes(metric))fail('طريقة المتابعة لا تناسب نوع التحدي');if(metric==='manual_value'&&!['sum','highest'].includes(scoring))fail('اختار طريقة حساب مناسبة');if(metric!=='manual_value'&&metric!=='workout_max'&&scoring!=='daily')fail('اختار طريقة حساب مناسبة');if(metric==='workout_max'&&scoring!=='highest')fail('اختار طريقة حساب مناسبة');
 const start=date(body.start??base.start??today());
 const end=date(body.end??base.end??new Date(Date.parse(start)+29*DAY).toISOString().slice(0,10));
 if(start<today())fail('تاريخ البداية لا يمكن ان يكون في الماضي');
 if(end<start||daysBetween(start,end)>365)fail('مدة التحدي لازم تكون من يوم الى 366 يوم');
 const target=number(body.target??base.target,0.01,100000000,['manual_value','workout_max','nutrition_days','water_days'].includes(metric));
 const exerciseKey=text(body.exerciseKey??base.exerciseKey,120)||null;if(metric==='workout_max'&&!exerciseKey)fail('اكتب اسم التمرين');
 const title=text(body.title??base.title);if(!title)fail('اكتب اسم التحدي');
 const maxMembers=Math.round(number(body.maxMembers??base.maxMembers??20,2,100,true));
 return {title,description:text(body.description??base.description,1000),kind,metric,target,unit:text(body.unit??base.unit,24),scoring,exerciseKey,start,end,weekdays:uniqueWeekdays(body.weekdays??base.weekdays),sharing:shareRules(body.sharing??base.sharing),maxMembers};
}
function create(userId,body={}){
 let base={};let source=null;
 if(body.sourcePersonalId){
  const personal=db.prepare('SELECT * FROM forma_challenges WHERE id=? AND owner_id=?').get(text(body.sourcePersonalId,80),userId);
  if(!personal)fail('التحدي الشخصي غير موجود',404);
  const p=parseJson(personal.payload,{});source=personal.id;base={title:p.title,description:p.description,kind:p.type,start:p.start,end:new Date(Date.parse(p.start)+(Number(p.duration||30)-1)*DAY).toISOString().slice(0,10),weekdays:p.weekdays};
 }
 const input=normalizeInput(body,base),id=randomUUID(),at=nowIso();
 db.exec('BEGIN;');
 try{
  db.prepare('INSERT INTO friend_challenges(id,owner_id,source_personal_id,title,description,kind,metric,target,unit,scoring,exercise_key,start_date,end_date,weekdays_json,share_json,status,max_members,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)')
   .run(id,userId,source,input.title,input.description,input.kind,input.metric,input.target,input.unit,input.scoring,input.exerciseKey,input.start,input.end,JSON.stringify(input.weekdays),JSON.stringify(input.sharing),'active',input.maxMembers,at,at);
  const user=db.prepare('SELECT name FROM users WHERE id=?').get(userId);
  db.prepare('INSERT INTO friend_challenge_members(challenge_id,user_id,role,status,display_name,invited_by,joined_at) VALUES(?,?,?,?,?,?,?)')
   .run(id,userId,'owner','active',text(user&&user.name,40)||'صاحب التحدي',null,at);
  db.exec('COMMIT;');
 }catch(error){try{db.exec('ROLLBACK;');}catch(_){}throw error;}
 return detail(id,userId);
}
function list(userId){return db.prepare(`SELECT c.* FROM friend_challenges c JOIN friend_challenge_members m ON m.challenge_id=c.id WHERE m.user_id=? AND m.status='active' ORDER BY CASE WHEN c.status='active' THEN 0 ELSE 1 END,c.updated_at DESC LIMIT 200`).all(userId).map(challenge=>{const mine=scoreStats(challenge,userId);return {...publicChallenge(challenge),role:challenge.owner_id===userId?'owner':'member',mine,participantCount:activeCount(challenge.id),pendingCount:challenge.owner_id===userId?pendingCount(challenge.id):0};});}
function activeCount(id){return Number((db.prepare("SELECT COUNT(*) AS n FROM friend_challenge_members WHERE challenge_id=? AND status='active'").get(id)||{}).n)||0;}
function pendingCount(id){return Number((db.prepare("SELECT COUNT(*) AS n FROM friend_challenge_join_requests WHERE challenge_id=? AND status='pending'").get(id)||{}).n)||0;}
function entryStats(challenge,userId){const r=db.prepare('SELECT COUNT(*) AS completed,COALESCE(SUM(points),0) AS total,COALESCE(MAX(value),0) AS highest FROM friend_challenge_entries WHERE challenge_id=? AND user_id=? AND day BETWEEN ? AND ? AND value>0').get(challenge.id,userId,challenge.start_date,challenge.end_date)||{};return {completed:Number(r.completed)||0,total:Number(r.total)||0,highest:Number(r.highest)||0};}
function autoStats(challenge,userId){
 if(challenge.metric==='workout_days'){
  const from=new Date(Date.parse(challenge.start_date)-DAY).toISOString().slice(0,10),to=new Date(Date.parse(challenge.end_date)+DAY).toISOString().slice(0,10);
  const rows=db.prepare("SELECT finished_at FROM workout_sessions WHERE user_id=? AND status='completed' AND substr(finished_at,1,10) BETWEEN ? AND ?").all(userId,from,to);const days=new Set(rows.map(r=>cairoDay(r.finished_at)).filter(day=>scheduled(challenge,day)));const n=days.size;return {completed:n,total:n,highest:0};
 }
 if(challenge.metric==='workout_max'){
  const from=new Date(Date.parse(challenge.start_date)-DAY).toISOString().slice(0,10),to=new Date(Date.parse(challenge.end_date)+DAY).toISOString().slice(0,10),params=[userId,from,to];let filter='';if(challenge.exercise_key){filter=' AND (ws.exercise_key=? OR ws.exercise_name=?)';params.push(challenge.exercise_key,challenge.exercise_key);}
  const rows=db.prepare("SELECT ws.weight,s.finished_at FROM workout_sets ws JOIN workout_sessions s ON s.id=ws.session_id WHERE s.user_id=? AND s.status='completed' AND ws.completed=1 AND substr(s.finished_at,1,10) BETWEEN ? AND ?"+filter).all(...params);const n=rows.filter(r=>{const day=cairoDay(r.finished_at);return day>=challenge.start_date&&day<=challenge.end_date;}).reduce((best,r)=>Math.max(best,Number(r.weight)||0),0);return {completed:n>0?1:0,total:n,highest:n};
 }
 if(challenge.metric==='nutrition_days'){
  const low=Number(challenge.target)*0.9,high=Number(challenge.target)*1.1;
  const rows=db.prepare('SELECT day FROM nutrition_days WHERE user_id=? AND day BETWEEN ? AND ? AND calories BETWEEN ? AND ?').all(userId,challenge.start_date,challenge.end_date,low,high);const n=rows.filter(r=>scheduled(challenge,r.day)).length;return {completed:n,total:n,highest:0};
 }
 if(challenge.metric==='water_days'){
  const rows=db.prepare('SELECT day FROM nutrition_days WHERE user_id=? AND day BETWEEN ? AND ? AND water_ml>=?').all(userId,challenge.start_date,challenge.end_date,challenge.target);const n=rows.filter(r=>scheduled(challenge,r.day)).length;return {completed:n,total:n,highest:0};
 }
 return entryStats(challenge,userId);
}
function scoreStats(challenge,userId){
 const membership=member(challenge.id,userId),joined=membership?cairoDay(membership.joined_at):challenge.start_date,scoreStart=joined>challenge.start_date?joined:challenge.start_date,scoped={...challenge,start_date:scoreStart};
 const raw=autoStats(scoped,userId),score=challenge.scoring==='highest'?raw.highest:raw.total;
 const expected=scheduledCount(scoped,today()),totalDays=scheduledCount(scoped,scoped.end_date),completed=Math.min(raw.completed,totalDays||raw.completed),missed=Math.max(0,expected-completed);
 let progress=0;if(challenge.scoring==='highest'&&challenge.target)progress=Math.min(100,Math.round(score/challenge.target*100));else if(challenge.scoring==='sum'&&challenge.target)progress=Math.min(100,Math.round(score/challenge.target*100));else progress=totalDays?Math.min(100,Math.round(completed/totalDays*100)):0;
 const consistency=expected?Math.min(100,Math.round(completed/expected*100)):0;
 return {score:Math.round(score*100)/100,completedDays:completed,missedDays:missed,expectedDays:expected,totalDays,progress,consistency};
}
function leaderboardFor(challenge){
 const members=db.prepare("SELECT user_id,display_name,joined_at FROM friend_challenge_members WHERE challenge_id=? AND status='active' ORDER BY joined_at,user_id").all(challenge.id);
 const ranked=members.map(m=>({userId:m.user_id,displayName:m.display_name,joinedAt:m.joined_at,...scoreStats(challenge,m.user_id)})).sort((a,b)=>b.score-a.score||b.consistency-a.consistency||a.joinedAt.localeCompare(b.joinedAt)||a.userId-b.userId);
 return ranked.map((item,index)=>({rank:index+1,displayName:item.displayName,score:item.score,completedDays:item.completedDays,missedDays:item.missedDays,progress:item.progress,consistency:item.consistency,userId:item.userId}));
}
function finalizeChallenge(challenge,status){
 const ranking=leaderboardFor(challenge),at=nowIso();db.exec('BEGIN;');try{db.prepare('UPDATE friend_challenges SET status=?,updated_at=? WHERE id=? AND status=\'active\'').run(status,at,challenge.id);db.prepare('DELETE FROM friend_challenge_results WHERE challenge_id=?').run(challenge.id);const insert=db.prepare('INSERT INTO friend_challenge_results(challenge_id,user_id,rank,score,stats_json,finalized_at) VALUES(?,?,?,?,?,?)');for(const item of ranking)insert.run(challenge.id,item.userId,item.rank,item.score,JSON.stringify({completedDays:item.completedDays,missedDays:item.missedDays,progress:item.progress,consistency:item.consistency}),at);db.prepare('UPDATE friend_challenge_invites SET revoked_at=? WHERE challenge_id=? AND revoked_at IS NULL').run(at,challenge.id);db.exec('COMMIT;');}catch(error){try{db.exec('ROLLBACK;');}catch(_){}throw error;}return row(challenge.id);
}
function detail(id,userId){
 let {challenge,membership}=visible(id,userId);if(challenge.status==='active'&&effectiveStatus(challenge)==='ended')challenge=finalizeChallenge(challenge,'completed');const leaders=leaderboardFor(challenge),mine=leaders.find(x=>x.userId===userId)||scoreStats(challenge,userId);
 const result={...publicChallenge(challenge),role:challenge.owner_id===userId?'owner':membership.role,participantCount:activeCount(id),pendingCount:challenge.owner_id===userId?pendingCount(id):0,mine:{...mine,userId:undefined},leaderboard:leaders.map(x=>challenge.owner_id===userId?{...x,memberId:x.userId,isMe:x.userId===userId,userId:undefined}:{...x,isMe:x.userId===userId,userId:undefined}),canInvite:effectiveStatus(challenge)==='active',canLog:effectiveStatus(challenge)==='active'&&scheduled(challenge,today())};
 const entries=db.prepare('SELECT day,value,points,source,note FROM friend_challenge_entries WHERE challenge_id=? AND user_id=? ORDER BY day').all(id,userId);result.myEntries=entries;
 if(challenge.owner_id===userId)result.requests=requestList(id,userId);
 if(challenge.status!=='active')result.finalResults=db.prepare('SELECT r.rank,r.score,r.stats_json,m.display_name FROM friend_challenge_results r JOIN friend_challenge_members m ON m.challenge_id=r.challenge_id AND m.user_id=r.user_id WHERE r.challenge_id=? ORDER BY r.rank').all(id).map(r=>({rank:r.rank,score:r.score,displayName:r.display_name,stats:parseJson(r.stats_json,{})}));
 return result;
}
function generateCode(){const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';const bytes=randomBytes(8);let raw='';for(let i=0;i<8;i++)raw+=alphabet[bytes[i]%alphabet.length];return raw.slice(0,4)+'-'+raw.slice(4);}
function normalizedCode(value){return text(value,40).toUpperCase().replace(/[^A-Z0-9]/g,'');}
function codeHash(value){return createHash('sha256').update(normalizedCode(value)).digest('hex');}
function createInvite(id,userId,options={}){
 const challenge=row(id);if(!challenge)fail('التحدي غير موجود',404);activeMember(id,userId);if(effectiveStatus(challenge)!=='active')fail('التحدي انتهى');
 let code,hash;do{code=generateCode();hash=codeHash(code);}while(db.prepare('SELECT 1 FROM friend_challenge_invites WHERE code_hash=?').get(hash));
 const inviteId=randomUUID(),days=Math.round(number(options.validDays??7,1,30,true)),remaining=Math.max(1,challenge.max_members-activeCount(id)),maxUses=Math.min(remaining,Math.round(number(options.maxUses??remaining,1,100,true))),expires=new Date(Date.now()+days*DAY).toISOString();
 db.prepare('INSERT INTO friend_challenge_invites(id,challenge_id,created_by,code_hash,code_hint,expires_at,max_uses,uses,created_at) VALUES(?,?,?,?,?,?,?,?,?)').run(inviteId,id,userId,hash,code.slice(-4),expires,maxUses,0,nowIso());
 const base=String(process.env.EF_BASE_URL||'https://elforma.onrender.com').replace(/\/$/,'');return {code,link:base+'/challenge/join/'+code,expiresAt:expires,maxUses};
}
function inviteByCode(code){const invite=db.prepare('SELECT * FROM friend_challenge_invites WHERE code_hash=?').get(codeHash(code));if(!invite||invite.revoked_at||invite.expires_at<=nowIso()||invite.uses>=invite.max_uses)fail('الدعوة غير متاحة',404);const challenge=row(invite.challenge_id);if(!challenge||effectiveStatus(challenge)!=='active'||activeCount(challenge.id)>=challenge.max_members)fail('التحدي لا يقبل مشاركين جدد',409);return {invite,challenge};}
function preview(code,userId){const {invite,challenge}=inviteByCode(code),existing=member(challenge.id,userId),request=db.prepare('SELECT status FROM friend_challenge_join_requests WHERE challenge_id=? AND user_id=?').get(challenge.id,userId);return {...publicChallenge(challenge),participantCount:activeCount(challenge.id),invitedBy:(db.prepare('SELECT display_name FROM friend_challenge_members WHERE challenge_id=? AND user_id=?').get(challenge.id,invite.created_by)||{}).display_name||'احد المشاركين',membershipStatus:existing&&existing.status==='active'?'active':request&&request.status||null,privacyText:privacyText(challenge)};}
function privacyText(challenge){const share=parseJson(challenge.share_json,{}),parts=['السكور','نسبة التقدم'];if(share.workoutSummary)parts.push('ملخص التمرين');if(share.nutritionSummary)parts.push('ملخص الالتزام بالتغذية');return 'المشاركون سيشاهدون '+parts.join(' و ')+' فقط';}
function requestJoin(code,userId,displayName){const {invite,challenge}=inviteByCode(code);if(challenge.owner_id===userId||member(challenge.id,userId)?.status==='active')return detail(challenge.id,userId);const name=text(displayName,40);if(!name)fail('اكتب الاسم الذي سيظهر للمشاركين');const at=nowIso();db.prepare(`INSERT INTO friend_challenge_join_requests(challenge_id,user_id,invite_id,invited_by,display_name,status,requested_at,decided_at,decided_by) VALUES(?,?,?,?,?,'pending',?,NULL,NULL) ON CONFLICT(challenge_id,user_id) DO UPDATE SET invite_id=excluded.invite_id,invited_by=excluded.invited_by,display_name=excluded.display_name,status='pending',requested_at=excluded.requested_at,decided_at=NULL,decided_by=NULL`).run(challenge.id,userId,invite.id,invite.created_by,name,at);return {challengeId:challenge.id,status:'pending',message:'تم ارسال طلبك لصاحب التحدي'};}
function requestList(id,userId){const challenge=row(id);if(!challenge||challenge.owner_id!==userId)fail('غير مسموح',403);return db.prepare(`SELECT r.user_id,r.display_name,r.requested_at,m.display_name AS invited_by_name FROM friend_challenge_join_requests r LEFT JOIN friend_challenge_members m ON m.challenge_id=r.challenge_id AND m.user_id=r.invited_by WHERE r.challenge_id=? AND r.status='pending' ORDER BY r.requested_at`).all(id).map(r=>({userId:r.user_id,displayName:r.display_name,requestedAt:r.requested_at,invitedBy:r.invited_by_name||'احد المشاركين'}));}
function decide(id,ownerId,targetUserId,approve){
 const challenge=row(id);if(!challenge||challenge.owner_id!==ownerId)fail('غير مسموح',403);const request=db.prepare("SELECT * FROM friend_challenge_join_requests WHERE challenge_id=? AND user_id=? AND status='pending'").get(id,targetUserId);if(!request)fail('الطلب غير موجود',404);
 db.exec('BEGIN;');try{
  const invite=db.prepare('SELECT * FROM friend_challenge_invites WHERE id=?').get(request.invite_id);if(approve){if(!invite||invite.revoked_at||invite.expires_at<=nowIso()||invite.uses>=invite.max_uses)fail('الدعوة انتهت');if(activeCount(id)>=challenge.max_members)fail('التحدي وصل للعدد الاقصى');const at=nowIso();db.prepare(`INSERT INTO friend_challenge_members(challenge_id,user_id,role,status,display_name,invited_by,joined_at,left_at) VALUES(?,?,'member','active',?,?,?,NULL) ON CONFLICT(challenge_id,user_id) DO UPDATE SET status='active',display_name=excluded.display_name,invited_by=excluded.invited_by,joined_at=excluded.joined_at,left_at=NULL`).run(id,targetUserId,request.display_name,request.invited_by,at);db.prepare('UPDATE friend_challenge_invites SET uses=uses+1 WHERE id=?').run(invite.id);}
  db.prepare('UPDATE friend_challenge_join_requests SET status=?,decided_at=?,decided_by=? WHERE challenge_id=? AND user_id=?').run(approve?'approved':'rejected',nowIso(),ownerId,id,targetUserId);db.exec('COMMIT;');
 }catch(error){try{db.exec('ROLLBACK;');}catch(_){}throw error;}
 return detail(id,ownerId);
}
function logEntry(id,userId,value,note='',at=today()){
 const challenge=row(id);if(!challenge)fail('التحدي غير موجود',404);const membership=activeMember(id,userId);if(effectiveStatus(challenge)!=='active')fail('التحدي انتهى');const day=date(at),joined=cairoDay(membership.joined_at);if(day>today())fail('لا يمكن تسجيل يوم قادم');if(day<joined)fail('لا يمكن التسجيل قبل الانضمام');if(!scheduled(challenge,day))fail('اليوم خارج ايام التحدي');if(['workout_days','workout_max','nutrition_days','water_days'].includes(challenge.metric))fail('النتيجة تتحدث تلقائيا من بياناتك');
 let numeric;if(challenge.metric==='manual_daily')numeric=value===true||Number(value)>0?1:0;else numeric=number(value,0,100000000,true);let points=challenge.scoring==='daily'?(numeric>0?1:0):numeric;
 const atIso=nowIso();db.prepare(`INSERT INTO friend_challenge_entries(challenge_id,user_id,day,value,points,source,note,created_at,updated_at) VALUES(?,?,?,?,?,'manual',?,?,?) ON CONFLICT(challenge_id,user_id,day) DO UPDATE SET value=excluded.value,points=excluded.points,note=excluded.note,updated_at=excluded.updated_at`).run(id,userId,day,numeric,points,text(note,200),atIso,atIso);return detail(id,userId);
}
function leave(id,userId){const challenge=row(id);if(!challenge)fail('التحدي غير موجود',404);if(challenge.owner_id===userId)fail('صاحب التحدي يقفله بدل المغادرة');activeMember(id,userId);db.prepare("UPDATE friend_challenge_members SET status='left',left_at=? WHERE challenge_id=? AND user_id=?").run(nowIso(),id,userId);return {ok:true};}
function removeMember(id,ownerId,targetUserId){const challenge=row(id);if(!challenge||challenge.owner_id!==ownerId)fail('غير مسموح',403);if(Number(targetUserId)===Number(ownerId))fail('لا يمكن حذف صاحب التحدي');db.prepare("UPDATE friend_challenge_members SET status='removed',left_at=? WHERE challenge_id=? AND user_id=? AND status='active'").run(nowIso(),id,targetUserId);return detail(id,ownerId);}
function revokeInvites(id,ownerId){const challenge=row(id);if(!challenge||challenge.owner_id!==ownerId)fail('غير مسموح',403);db.prepare('UPDATE friend_challenge_invites SET revoked_at=? WHERE challenge_id=? AND revoked_at IS NULL').run(nowIso(),id);return {ok:true};}
function close(id,ownerId){const challenge=row(id);if(!challenge||challenge.owner_id!==ownerId)fail('غير مسموح',403);if(challenge.status!=='active')return detail(id,ownerId);finalizeChallenge(challenge,'closed');return detail(id,ownerId);}
function exportUser(userId){return {owned:db.prepare('SELECT * FROM friend_challenges WHERE owner_id=?').all(userId).map(publicChallenge),memberships:db.prepare('SELECT * FROM friend_challenge_members WHERE user_id=?').all(userId),entries:db.prepare('SELECT * FROM friend_challenge_entries WHERE user_id=?').all(userId),joinRequests:db.prepare('SELECT * FROM friend_challenge_join_requests WHERE user_id=?').all(userId)};}
module.exports={create,list,detail,createInvite,preview,requestJoin,requestList,decide,logEntry,leave,removeMember,revokeInvites,close,exportUser,scoreStats,leaderboardFor,normalizedCode,cairoDay};
