'use strict';
// Independent community domain; never writes nutrition plans or workout data.
const { randomUUID } = require('node:crypto');
const { db } = require('./db');
const DAY = 86400000;
db.exec(`
CREATE TABLE IF NOT EXISTS forma_recipes (
 id TEXT PRIMARY KEY, payload TEXT NOT NULL, published INTEGER NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS forma_challenges (
 id TEXT PRIMARY KEY, owner_id INTEGER, payload TEXT NOT NULL,
 published INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS forma_challenge_members (
 challenge_id TEXT NOT NULL, user_id INTEGER NOT NULL, display_name TEXT NOT NULL,
 joined_at TEXT NOT NULL, PRIMARY KEY(challenge_id,user_id),
 FOREIGN KEY(challenge_id) REFERENCES forma_challenges(id) ON DELETE CASCADE,
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS forma_challenge_days (
 challenge_id TEXT NOT NULL, user_id INTEGER NOT NULL, day TEXT NOT NULL,
 checked_at TEXT NOT NULL, PRIMARY KEY(challenge_id,user_id,day),
 FOREIGN KEY(challenge_id,user_id) REFERENCES forma_challenge_members(challenge_id,user_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_forma_owner ON forma_challenges(owner_id,updated_at);
CREATE INDEX IF NOT EXISTS idx_forma_members_user ON forma_challenge_members(user_id);
`);
const fail = (message, status=400) => { const e = new Error(message); e.status=status; throw e; };
function text(v,max=120){return String(v??'').trim().slice(0,max);}
function integer(v,min,max,fallback){if(v==null||v==='')return fallback;const n=Number(v);if(!Number.isInteger(n)||n<min||n>max)fail('قيمة رقمية غير صالحة');return n;}
function real(v,min,max){if(v==null||v==='')return null;const n=Number(v);if(!Number.isFinite(n)||n<min||n>max)fail('قيمة رقمية غير صالحة');return n;}
function date(v){const s=text(v,10);const d=new Date(s+'T00:00:00Z');if(!/^\d{4}-\d{2}-\d{2}$/.test(s)||!Number.isFinite(+d)||d.toISOString().slice(0,10)!==s)fail('تاريخ غير صالح');return s;}
function image(v){const s=text(v,500);if(!s)return '';if(/^\/uploads\/images\/img_[\w.-]+$/.test(s))return s;try{const u=new URL(s);if(u.protocol==='https:'&&!u.username&&!u.password)return u.href;}catch(_){}fail('الصورة تحتاج رابط HTTPS أو صورة مرفوعة');}
function lines(v,max=40){const a=Array.isArray(v)?v:String(v??'').split('\n');return a.map(x=>text(x,500)).filter(Boolean).slice(0,max);}
function today(payload,now=new Date()){
 if(payload.team)return new Intl.DateTimeFormat('en-CA',{timeZone:'Africa/Cairo',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);
 return new Date(+now+(payload.offsetMinutes||0)*60000).toISOString().slice(0,10);
}
function daysBetween(a,b){return Math.round((Date.parse(b)-Date.parse(a))/DAY);}
function scheduled(p,day){const n=daysBetween(p.start,day);return n>=0&&n<p.duration&&p.weekdays.includes(new Date(day+'T12:00:00Z').getUTCDay());}
function expected(p,until){let n=0;for(let i=0;i<p.duration;i++){const d=new Date(Date.parse(p.start)+i*DAY).toISOString().slice(0,10);if(d<=until&&scheduled(p,d))n++;}return n;}
function recipeInput(b){const p={title:text(b.title),image:image(b.image),ingredients:lines(b.ingredients),preparation:lines(b.preparation),highlights:lines(b.highlights,12),calories:real(b.calories,0,10000),protein:real(b.protein,0,1000),carbs:real(b.carbs,0,1000),fat:real(b.fat,0,1000),cost:real(b.cost,0,100000),currency:['EGP','USD'].includes(b.currency)?b.currency:'EGP',servings:integer(b.servings,1,50,1),points:integer(b.points,0,10000,0),published:b.published===true};if(!p.title||!p.ingredients.length||!p.preparation.length)fail('اسم الوصفة والمكونات وطريقة التحضير مطلوبة');return p;}
function challengeInput(b,team){
 const p={title:text(b.title),description:text(b.description,2000),image:image(b.image),type:['custom','movement','nutrition','water','sleep'].includes(b.type)?b.type:'custom',start:date(b.start),duration:integer(b.duration,1,365,30),reminderTime:text(b.reminderTime,5),offsetMinutes:team?180:integer(b.offsetMinutes,-720,840,180),weekdays:Array.isArray(b.weekdays)?[...new Set(b.weekdays.map(Number))].sort():[0,1,2,3,4,5,6],team,published:team?b.published===true:true};
 if(!p.title||!p.weekdays.length||p.weekdays.some(d=>!Number.isInteger(d)||d<0||d>6))fail('اسم التحدي والأيام مطلوبة');
 if(p.reminderTime&&!/^([01]\d|2[0-3]):[0-5]\d$/.test(p.reminderTime))fail('وقت غير صالح');return p;
}
function unpack(r){return r?{...JSON.parse(r.payload),id:r.id,createdAt:r.created_at,updatedAt:r.updated_at}:null;}
function recipes(admin=false){return db.prepare('SELECT * FROM forma_recipes'+(admin?'':' WHERE published=1')+' ORDER BY updated_at DESC LIMIT 200').all().map(unpack);}
function saveRecipe(b){const p=recipeInput(b),old=b.id?db.prepare('SELECT * FROM forma_recipes WHERE id=?').get(text(b.id)):null;if(b.id&&!old)fail('الوصفة غير موجودة',404);const id=old?.id||randomUUID(),now=new Date().toISOString();db.prepare('INSERT INTO forma_recipes VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,published=excluded.published,updated_at=excluded.updated_at').run(id,JSON.stringify(p),+p.published,old?.created_at||now,now);return {...p,id};}
function getRow(id){return db.prepare('SELECT * FROM forma_challenges WHERE id=?').get(text(id));}
function accessible(id,userId,admin=false){const r=getRow(id);if(!r||(!admin&&(r.owner_id!=null?r.owner_id!==userId:!r.published)))fail('التحدي غير متاح',404);return r;}
function saveChallenge(b,userId,admin=false){
 const old=b.id?accessible(b.id,userId,admin):null;
 if(old&&(admin?old.owner_id!=null:old.owner_id!==userId))fail('غير مسموح',403);
 const p=challengeInput(b,admin),id=old?.id||randomUUID(),now=new Date().toISOString();
 if(!old&&p.start<today(p))fail('بداية التحدي تكون اليوم أو بعده');
 if(old){const before=unpack(old),participants=db.prepare('SELECT COUNT(*) AS n FROM forma_challenge_members WHERE challenge_id=?').get(id).n;
 const checks=db.prepare('SELECT COUNT(*) AS n FROM forma_challenge_days WHERE challenge_id=?').get(id).n;
 if((admin&&participants>0)||checks>0){for(const k of ['start','type','weekdays','offsetMinutes'])if(JSON.stringify(p[k])!==JSON.stringify(before[k]))fail('لا يمكن تغيير قواعد التحدي بعد بدء المشاركة');if(p.duration<before.duration)fail('لا يمكن تقصير تحدٍ بدأ تسجيله');if(admin&&p.duration!==before.duration)fail('مدة تحدي الفريق ثابتة بعد الانضمام');}
 }
 if(!old&&!admin&&db.prepare('SELECT COUNT(*) AS n FROM forma_challenges WHERE owner_id=?').get(userId).n>=50)fail('الحد الأقصى 50 تحديًا شخصيًا');
 db.prepare('INSERT INTO forma_challenges VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,published=excluded.published,updated_at=excluded.updated_at').run(id,admin?null:userId,JSON.stringify(p),+p.published,old?.created_at||now,now);
 if(!admin)db.prepare('INSERT OR IGNORE INTO forma_challenge_members VALUES(?,?,?,?)').run(id,userId,'أنا',now);
 return {...p,id};
}
function memberStats(p,row,now){const completed=Number(row.completed)||0,elapsed=expected(p,today(p,now)),total=expected(p,'9999-12-31');return {displayName:row.display_name,completed,elapsed,total,consistency:elapsed?Math.round(completed/elapsed*100):0,progress:total?Math.round(completed/total*100):0};}
function detail(id,userId,now=new Date()){
 const r=accessible(id,userId),p=unpack(r),day=today(p,now);
 const member=db.prepare('SELECT * FROM forma_challenge_members WHERE challenge_id=? AND user_id=?').get(id,userId);
 const checked=member?db.prepare('SELECT day FROM forma_challenge_days WHERE challenge_id=? AND user_id=? ORDER BY day').all(id,userId).map(r=>r.day):[];
 const participantCount=db.prepare('SELECT COUNT(*) AS n FROM forma_challenge_members WHERE challenge_id=?').get(id).n;
 // No user IDs, e-mail addresses or phone numbers are exposed to other members.
 const leaders=p.team?db.prepare(`SELECT m.display_name,m.user_id,COUNT(d.day) AS completed FROM forma_challenge_members m LEFT JOIN forma_challenge_days d ON d.challenge_id=m.challenge_id AND d.user_id=m.user_id WHERE m.challenge_id=? GROUP BY m.user_id,m.display_name,m.joined_at ORDER BY completed DESC,m.joined_at ASC,m.user_id ASC LIMIT 3`).all(id).map((row,index)=>({...memberStats(p,row,now),rank:index+1,isMe:row.user_id===userId})):[];
 const mine=memberStats(p,{display_name:member?.display_name||'',completed:checked.length},now);
 return {...p,today:day,ended:daysBetween(p.start,day)>=p.duration,canCheck:!!member&&scheduled(p,day),joined:!!member,participantCount,checkedDays:checked,checkedToday:checked.includes(day),mine,leaders};
}
function list(userId){return db.prepare('SELECT * FROM forma_challenges WHERE owner_id=? OR (owner_id IS NULL AND published=1) ORDER BY updated_at DESC LIMIT 250').all(userId).map(r=>detail(r.id,userId));}
function adminChallenges(){return db.prepare('SELECT * FROM forma_challenges WHERE owner_id IS NULL ORDER BY updated_at DESC LIMIT 200').all().map(r=>({...unpack(r),participantCount:db.prepare('SELECT COUNT(*) AS n FROM forma_challenge_members WHERE challenge_id=?').get(r.id).n}));}
function join(id,userId,displayName){const r=accessible(id,userId),p=unpack(r);if(!p.team)fail('هذا تحدٍ شخصي');if(daysBetween(p.start,today(p))>=p.duration)fail('انتهى التحدي');const name=text(displayName,40);if(!name)fail('اكتب اسم العرض');db.prepare('INSERT OR IGNORE INTO forma_challenge_members VALUES(?,?,?,?)').run(id,userId,name,new Date().toISOString());return detail(id,userId);}
function check(id,userId,done,now=new Date()){
 if(typeof done!=='boolean')fail('حالة التسجيل غير صالحة');const r=accessible(id,userId),p=unpack(r),day=today(p,now);
 if(!db.prepare('SELECT 1 FROM forma_challenge_members WHERE challenge_id=? AND user_id=?').get(id,userId))fail('انضم للتحدي أولًا',403);
 if(!scheduled(p,day))fail('لا يوجد تسجيل متاح لهذا اليوم');
 if(done)db.prepare('INSERT OR IGNORE INTO forma_challenge_days VALUES(?,?,?,?)').run(id,userId,day,now.toISOString());
 else db.prepare('DELETE FROM forma_challenge_days WHERE challenge_id=? AND user_id=? AND day=?').run(id,userId,day);
 return detail(id,userId,now);
}
function remove(id,userId){const r=accessible(id,userId);if(r.owner_id!==userId)fail('غير مسموح',403);db.prepare('DELETE FROM forma_challenges WHERE id=? AND owner_id=?').run(id,userId);}
function exportUser(userId){return {personalChallenges:db.prepare('SELECT * FROM forma_challenges WHERE owner_id=?').all(userId).map(unpack),memberships:db.prepare('SELECT * FROM forma_challenge_members WHERE user_id=?').all(userId),days:db.prepare('SELECT * FROM forma_challenge_days WHERE user_id=?').all(userId)};}
module.exports={exportUser,recipes,saveRecipe,saveChallenge,detail,list,adminChallenges,join,check,remove,recipeInput,challengeInput,today,scheduled,expected};
