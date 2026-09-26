'use strict';
// Local HTTP integration: no real accounts, notifications or external service calls.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
process.env.EF_DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'ef-community-api-'));
process.env.EF_DATABASE_ENGINE = 'sqlite';
process.env.EF_ADMIN_EMAILS = 'admin@example.test';
process.env.PORT = '0';
const server = require('../server');
const {db} = require('../lib/db');
const {issueToken} = require('../lib/auth');
const community = require('../lib/community');
const now = new Date().toISOString();
for (const [id, email, verified] of [[101,'admin@example.test',1],[102,'a@example.test',1],[103,'b@example.test',1],[104,'unverified@example.test',0]]) {
  db.prepare('INSERT INTO users(id,email,name,pass_hash,pass_salt,verified,created_at) VALUES(?,?,?,?,?,?,?)').run(id,email,'Local tester','x','y',verified,now);
}
let checks = 0;
async function req(method, route, body, user) {
  const headers = {'Content-Type':'application/json'};
  if (user) headers.Cookie = 'ef_session=' + issueToken(user);
  const r = await fetch('http://127.0.0.1:' + server.address().port + route, {method,headers,body:body==null?undefined:JSON.stringify(body)});
  return {status:r.status,data:await r.json()};
}
async function check(name, fn) {await fn(); checks++; console.log('PASS',name);}
(async () => {
  await new Promise(r => server.listening?r():server.once('listening',r));
  await check('community requires authentication',async()=>assert.equal((await req('GET','/api/mobile/community')).status,401));
  await check('ordinary account cannot publish admin content',async()=>assert.equal((await req('POST','/api/admin/community/recipes',{},102)).status,403));
  const recipe={title:'طبق تجريبي',image:'/uploads/images/img_local.webp',ingredients:['مكون واحد'],preparation:['خطوة واحدة'],calories:300,published:true};
  await check('admin publishes recipe and mobile receives all details',async()=>{
    assert.equal((await req('POST','/api/admin/community/recipes',recipe,101)).status,200);
    const r=await req('GET','/api/mobile/community',null,102);
    assert.equal(r.data.recipes[0].calories,300);assert.deepEqual(r.data.recipes[0].preparation,recipe.preparation);
  });
  let id;
  const base={title:'تحدي محلي',start:community.today({team:true}),duration:7,weekdays:[0,1,2,3,4,5,6],offsetMinutes:180};
  await check('personal challenge HTTP creation and account isolation',async()=>{
    const r=await req('POST','/api/mobile/community/challenge',base,102);assert.equal(r.status,200);id=r.data.item.id;
    assert.equal((await req('GET','/api/mobile/community/detail?id='+id,null,103)).status,404);
    assert.equal((await req('POST','/api/mobile/community/delete',{id},103)).status,404);
  });
  await check('HTTP daily check is idempotent and validates boolean',async()=>{
    assert.equal((await req('POST','/api/mobile/community/check',{id,done:'true'},102)).status,400);
    await req('POST','/api/mobile/community/check',{id,done:true},102);
    const r=await req('POST','/api/mobile/community/check',{id,done:true},102);
    assert.equal(r.data.item.mine.completed,1);
  });
  let team;
  await check('published team challenge, join and top-three flow',async()=>{
    const r=await req('POST','/api/admin/community/challenges',{...base,published:true},101);assert.equal(r.status,200);team=r.data.item.id;
    assert.equal((await req('POST','/api/mobile/community/join',{id:team,displayName:'مشارك'},103)).data.item.participantCount,1);
    const checked=await req('POST','/api/mobile/community/check',{id:team,done:true},103);
    assert.equal(checked.data.item.leaders[0].displayName,'مشارك');assert.equal(checked.data.item.leaders[0].consistency,100);
  });
  await check('export contains own challenge history',async()=>{
    const r=await req('GET','/api/account/export',null,102);assert.equal(r.status,200);
    assert.equal(r.data.community.personalChallenges[0].id,id);assert.equal(r.data.community.days.length,1);
  });
  let secondId;
  await check('one account can create and list multiple personal challenges',async()=>{
    const second=await req('POST','/api/mobile/community/challenge',{...base,title:'تحدي شخصي ثاني'},102);
    assert.equal(second.status,200);secondId=second.data.item.id;assert.notEqual(secondId,id);
    const list=await req('GET','/api/mobile/community',null,102);
    const own=list.data.challenges.filter(x=>x.team!==true);
    assert(own.some(x=>x.id===id));assert(own.some(x=>x.id===secondId));
  });
  await check('second personal challenge can be removed independently',async()=>{
    assert.equal((await req('POST','/api/mobile/community/delete',{id:secondId},102)).status,200);
    assert.equal((await req('GET','/api/mobile/community/detail?id='+secondId,null,102)).status,404);
    assert.equal((await req('GET','/api/mobile/community/detail?id='+id,null,102)).status,200);
  });
  await check('malformed array body rejected',async()=>assert.equal((await req('POST','/api/mobile/community/challenge',[],102)).status,400));
  await check('personal deletion clears history',async()=>{
    assert.equal((await req('POST','/api/mobile/community/delete',{id},102)).status,200);
    assert.equal((await req('GET','/api/mobile/community/detail?id='+id,null,102)).status,404);
  });
  console.log(`${checks} community HTTP integration checks passed`);
  server.close(()=>{db.close();fs.rmSync(process.env.EF_DATA_DIR,{recursive:true,force:true});process.exit(0);});
})().catch(e=>{console.error(e);server.close(()=>process.exit(1));});
