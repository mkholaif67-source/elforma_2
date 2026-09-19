'use strict';
const domain=require('../lib/community');
const auth=require('../lib/auth');
const cfg=require('../lib/config');
const db=require('../lib/db');
const {parseCookies,sendJson,readJsonBody}=require('../lib/util');
const {rateLimit}=require('../lib/rateLimit');
async function handle(req,res,pathname,ip){
 const isAdmin=pathname.startsWith('/api/admin/');
 const u=auth.currentUser(parseCookies(req));
 if(!u)return sendJson(res,401,{error:'unauthenticated'});
 if(isAdmin&&(!u.verified||!cfg.isAdminEmail(u.email)))return sendJson(res,403,{error:'forbidden'});
 const write=req.method!=='GET';
 if(write&&!rateLimit('community:'+u.id,90,60000))return sendJson(res,429,{error:'انتظر قليلًا ثم حاول'});
 try {
  const b=write?await readJsonBody(req):{};
  if(!b || typeof b!=='object' || Array.isArray(b))return sendJson(res,400,{error:'bad_request'});
  let result;
  if(pathname==='/api/admin/community/recipes'&&req.method==='GET')result={items:domain.recipes(true)};
  else if(pathname==='/api/admin/community/recipes'&&req.method==='POST')result={item:domain.saveRecipe(b)};
  else if(pathname==='/api/admin/community/challenges'&&req.method==='GET')result={items:domain.adminChallenges()};
  else if(pathname==='/api/admin/community/challenges'&&req.method==='POST')result={item:domain.saveChallenge(b,u.id,true)};
  else if(pathname==='/api/mobile/community'&&req.method==='GET')result={recipes:domain.recipes(),challenges:domain.list(u.id)};
  else if(pathname==='/api/mobile/community/challenge'&&req.method==='POST')result={item:domain.saveChallenge(b,u.id)};
  else if(pathname==='/api/mobile/community/join'&&req.method==='POST')result={item:domain.join(b.id,u.id,b.displayName)};
  else if(pathname==='/api/mobile/community/check'&&req.method==='POST')result={item:domain.check(b.id,u.id,b.done)};
  else if(pathname==='/api/mobile/community/delete'&&req.method==='POST'){domain.remove(b.id,u.id);result={};}
  else if(pathname==='/api/mobile/community/detail'&&req.method==='GET')result={item:domain.detail(new URL(req.url,'http://localhost').searchParams.get('id'),u.id)};
  else return sendJson(res,404,{error:'not_found'});
  if(isAdmin&&write)db.audit(u.id,'admin_community:'+pathname+':'+(result.item?.id||''),ip);
  return sendJson(res,200,{ok:true,...result});
 }catch(e){if(e.status)return sendJson(res,e.status,{error:e.message});throw e;}
}
module.exports={handle};
