'use strict';
// Per-meal preferences; legacy main writes still apply to lunch + dinner.
const h=require('./db').db;
h.exec(`CREATE TABLE IF NOT EXISTS meal_food_preferences(
 user_id INTEGER NOT NULL,meal_slot TEXT NOT NULL,food_id TEXT NOT NULL,
 PRIMARY KEY(user_id,meal_slot,food_id),
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)`);
const slots=['breakfast','snack','pre','lunch','dinner','main'];
// Idempotent additive migration. Never re-import a removed legacy preference.
h.exec(`INSERT OR IGNORE INTO meal_food_preferences SELECT user_id,'lunch',food_id FROM meal_food_preferences WHERE meal_slot='main';
INSERT OR IGNORE INTO meal_food_preferences SELECT user_id,'dinner',food_id FROM meal_food_preferences WHERE meal_slot='main';
DELETE FROM meal_food_preferences WHERE meal_slot='main';`);
const get=h.prepare('SELECT meal_slot,food_id FROM meal_food_preferences WHERE user_id=? ORDER BY meal_slot,food_id');
function read(userId){
 const out={breakfast:[],snack:[],pre:[],lunch:[],dinner:[]};
 for(const row of get.all(userId))if(out[row.meal_slot])out[row.meal_slot].push(row.food_id);
 out.main=[...new Set([...out.lunch,...out.dinner])];return out;
}
function set(userId,slot,id,enabled){
 if(!slots.includes(slot))throw Error('invalid_meal_slot');
 const targets=slot==='main'?['lunch','dinner']:[slot],current=read(userId);
 for(const target of targets)if(enabled&&!current[target].includes(id)&&current[target].length>=20)throw Error('favorites_limit');
 if(slot==='main'){
  if(enabled)h.prepare('INSERT OR IGNORE INTO meal_food_preferences(user_id,meal_slot,food_id) VALUES(?,?,?),(?,?,?)').run(userId,'lunch',id,userId,'dinner',id);
  else h.prepare("DELETE FROM meal_food_preferences WHERE user_id=? AND meal_slot IN ('lunch','dinner') AND food_id=?").run(userId,id);
  return read(userId);
 }
 for(const target of targets){
  if(enabled)h.prepare('INSERT OR IGNORE INTO meal_food_preferences(user_id,meal_slot,food_id) VALUES(?,?,?)').run(userId,target,id);
  else h.prepare('DELETE FROM meal_food_preferences WHERE user_id=? AND meal_slot=? AND food_id=?').run(userId,target,id);
 }
 return read(userId);
}
module.exports={read,set,slots};
