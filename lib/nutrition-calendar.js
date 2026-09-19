'use strict';
// A single calendar seed for setup and every subsequent read.
function calendar(start, offsetMinutes=180, offsetDays=0, now=Date.now()){
 const localMs=now+offsetMinutes*60000,shiftedMs=localMs+offsetDays*86400000;
 const started=Date.parse(start)||now,sl=started+offsetMinutes*60000,mid=Math.floor(sl/86400000)*86400000;
 const effectiveStartMs=mid+86400000-sl<=43200000?mid+86400000-offsetMinutes*60000:started;
 return {localMs,date:new Date(shiftedMs).toISOString().slice(0,10),day:((Math.floor(shiftedMs/86400000)-18265)%7+7)%7,
 week:Math.max(1,Math.floor((localMs-effectiveStartMs)/604800000)+1),days:Math.floor((localMs-effectiveStartMs)/86400000)};
}
module.exports={calendar};
