'use strict';
const {EventEmitter}=require('node:events');
const events=new EventEmitter();events.setMaxListeners(0);
function changed(){events.emit('changed');}
function wait(res,ms=25000){return new Promise(resolve=>{
 let done=false;
 const finish=()=>{if(done)return;done=true;clearTimeout(timer);events.removeListener('changed',finish);res.removeListener('close',finish);resolve();};
 const timer=setTimeout(finish,ms);timer.unref?.();
 events.once('changed',finish);res.once('close',finish);
});}
module.exports={changed,wait};
