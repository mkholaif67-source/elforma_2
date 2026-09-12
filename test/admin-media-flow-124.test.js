'use strict';
// Exercise the actual HTTP wire format. Decode gzip exactly ONCE, as mobile clients do.
const assert=require('node:assert/strict'),http=require('node:http'),zlib=require('node:zlib'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
process.env.EF_DATA_DIR=fs.mkdtempSync(path.join(os.tmpdir(),'ef-gzip-flow-'));
process.env.PORT='0';process.env.EF_ADMIN_EMAILS='admin124@gmail.com';
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
 const db=require('../lib/db');
 const admin=await request('POST','/api/auth/signup',{email:'admin124@gmail.com',password:'StrongPassword123',name:'Admin test'});assert.equal(admin.status,201);const cookie=admin.cookie;
 db.db.prepare('UPDATE users SET verified=1 WHERE email=?').run('admin124@gmail.com');
 const videos=await request('GET','/api/admin/videos',null,cookie);assert.equal(videos.status,200);assert(videos.data.total>=180);for(const category of ['gym','home','modules'])assert(videos.data.items.some(x=>x.category===category));
 const uid=db.createUser('target124@gmail.com',null,'Target','h','s');
 const granted=await request('POST','/api/admin/user/subscription',{userId:uid,action:'grant',months:1},cookie);assert.equal(granted.status,200);
 const deleted=await request('POST','/api/admin/users/bulk',{userIds:[uid],action:'delete'},cookie);assert.equal(deleted.status,200);assert.equal(deleted.data.done,1);
 const audit=await request('GET','/api/admin/audit',null,cookie);assert.equal(audit.status,200);assert(audit.data.items.some(x=>x.action.startsWith('admin_sub:grant')));assert(audit.data.items.some(x=>x.action.startsWith('admin_user_delete:')));
 const base='http://127.0.0.1:'+server.address().port;
 const form=new FormData();const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aFZkAAAAASUVORK5CYII=','base64');form.append('image',new Blob([png],{type:'image/png'}),'test.png');
 const up=await fetch(base+'/api/admin/upload',{method:'POST',headers:{Cookie:cookie},body:form});assert.equal(up.status,200);const uploaded=await up.json();
 const publicImage=await fetch(base+uploaded.url);assert.equal(publicImage.status,200);assert.equal(publicImage.headers.get('content-type'),'image/png');assert.deepEqual(Buffer.from(await publicImage.arrayBuffer()),png);
 const save=await request('POST','/api/admin/announcements',{items:[{id:'test124',title:'',body:'',image:uploaded.url,layout:'imageOnly',imageAction:'phone',phone:'+201000000000',active:true}]},cookie);assert.equal(save.status,200);
 const boot=await request('GET','/api/mobile/bootstrap',null,cookie);assert.equal(boot.data.announcements[0].layout,'imageOnly');assert.equal(boot.data.announcements[0].imageAction,'phone');
 const note=await request('POST','/api/admin/notifications/send',{title:'Test',body:'Notification',phone:'+201000000000',image:uploaded.url},cookie);assert.equal(note.status,200);assert.equal(note.data.notification.link,'tel:+201000000000');
 const note2=await request('POST','/api/admin/notifications/send',{title:'Second',body:'Another'},cookie);assert.notEqual(note.data.notification.id,note2.data.notification.id);
 // Execute the actual frontend loaders against real server responses.
 const html=fs.readFileSync(path.join(__dirname,'../public/admin.html'),'utf8');const vm=require('node:vm');const elements={};const $=id=>elements[id]||(elements[id]={value:'',innerHTML:'',querySelectorAll:()=>[],appendChild:()=>{}});
 const sandbox={$ ,S:{},GET:async p=>({ok:true,data:p.includes('audit')?audit.data:videos.data}),adminFail:()=>{throw Error('frontend load failed')},toast:()=>{},document:{createElement:()=>({dataset:{}})},loadVideoReports:async()=>{},filterVids:()=>{},filterAudit:()=>{},console};vm.createContext(sandbox);
 for(const name of ['loadAudit','loadVids']){const start=html.indexOf('async function '+name+'(');const end=html.indexOf('\n}',start)+2;vm.runInContext(html.slice(start,end),sandbox);}
 vm.runInContext('let _auditAll=[];',sandbox);await sandbox.loadAudit();await sandbox.loadVids();assert(vm.runInContext('_auditAll.length',sandbox)>0);assert(sandbox.S.allVids.length===videos.data.total);
 console.log(JSON.stringify({result:'PASS',videos:videos.data.total,categories:[...new Set(videos.data.items.map(x=>x.category))],auditRows:audit.data.items.length,uploadReadable:true,imageOnlyRoundtrip:true,notificationPhone:true,adminLoaders:true}));
})().then(()=>server.close(()=>process.exit(0))).catch(e=>{console.error(e);server.close(()=>process.exit(1));});
