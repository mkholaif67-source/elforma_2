'use strict';

const domain = require('../lib/friend-challenges');
const auth = require('../lib/auth');
const { parseCookies, sendJson, readJsonBody } = require('../lib/util');
const { rateLimit } = require('../lib/rateLimit');

async function handle(req,res,pathname){
  const user=auth.currentUser(parseCookies(req));
  if(!user)return sendJson(res,401,{error:'سجل دخولك اولا'});
  const write=req.method!=='GET';
  if(write&&!rateLimit('friend-challenges:'+user.id,80,60000))return sendJson(res,429,{error:'حاول مرة اخرى بعد قليل'});
  try{
    const url=new URL(req.url,'http://localhost');
    const body=write?await readJsonBody(req):{};
    if(!body||typeof body!=='object'||Array.isArray(body))return sendJson(res,400,{error:'راجع البيانات وحاول مرة اخرى'});
    let result;
    if(req.method==='GET'&&pathname==='/api/mobile/friend-challenges')result={items:domain.list(user.id)};
    else if(req.method==='GET'&&pathname==='/api/mobile/friend-challenges/detail')result={item:domain.detail(url.searchParams.get('id'),user.id)};
    else if(req.method==='GET'&&pathname==='/api/mobile/friend-challenges/preview')result={item:domain.preview(url.searchParams.get('code'),user.id)};
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/create')result={item:domain.create(user.id,body)};
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/invite')result={invite:domain.createInvite(body.id,user.id,body)};
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/request')result=domain.requestJoin(body.code,user.id,body.displayName);
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/decide')result={item:domain.decide(body.id,user.id,Number(body.userId),body.approve===true)};
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/log'){const entryDay=body.day||domain.cairoDay(body.clientAt?new Date(body.clientAt):new Date());result={item:domain.logEntry(body.id,user.id,body.value,body.note,entryDay)};}
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/leave')result=domain.leave(body.id,user.id);
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/remove')result={item:domain.removeMember(body.id,user.id,Number(body.userId))};
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/revoke')result=domain.revokeInvites(body.id,user.id);
    else if(req.method==='POST'&&pathname==='/api/mobile/friend-challenges/close')result={item:domain.close(body.id,user.id)};
    else return sendJson(res,404,{error:'الصفحة غير موجودة'});
    return sendJson(res,200,{ok:true,...result});
  }catch(error){
    if(error&&error.status)return sendJson(res,error.status,{error:error.message});
    throw error;
  }
}

module.exports={handle};
