'use strict';
// Persist only the expensive ungated engine output, never subscription decisions.
// Keys cover the exact inputs, selected date, account and engine source version.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.join(__dirname,'..');
const sources=['lib/nutrition-engine-host.js','lib/nutrition-owner-policy.js','lib/nutrition-rules.js','lib/meal-serving-policy.js','lib/nutrition-plan-auditor.js','lib/egyptian-food-db.js','lib/age-policy.js'];
for(const f of fs.readdirSync(path.join(root,'app/diet/js')).filter(f=>f.endsWith('.js')).sort())sources.push('app/diet/js/'+f);
const engineVersion=crypto.createHash('sha256');for(const f of sources)engineVersion.update(f).update(fs.readFileSync(path.join(root,f)));
const version=engineVersion.digest('hex');let stmts;
function sql(){
 if(stmts)return stmts;
 const h=require('./db').db;
 h.exec(`CREATE TABLE IF NOT EXISTS nutrition_computations(
 user_id INTEGER NOT NULL,plan_day TEXT NOT NULL,context_hash TEXT NOT NULL,
 result_json TEXT NOT NULL,updated_at TEXT NOT NULL,
 PRIMARY KEY(user_id,plan_day),FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)`);
 stmts={get:h.prepare('SELECT context_hash,result_json FROM nutrition_computations WHERE user_id=? AND plan_day=?'),
 put:h.prepare(`INSERT INTO nutrition_computations(user_id,plan_day,context_hash,result_json,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(user_id,plan_day) DO UPDATE SET context_hash=excluded.context_hash,result_json=excluded.result_json,updated_at=excluded.updated_at`),
 prune:h.prepare('DELETE FROM nutrition_computations WHERE user_id=? AND plan_day NOT IN (SELECT plan_day FROM nutrition_computations WHERE user_id=? ORDER BY updated_at DESC,plan_day DESC LIMIT 8)')};return stmts;
}
function digest(profile,inputs){return crypto.createHash('sha256').update(version).update(JSON.stringify({profile,inputs})).digest('hex');}
function read(userId,day,hash){
 try{const r=sql().get.get(userId,day);if(r&&r.context_hash===hash){const value=JSON.parse(r.result_json);if(value.plan&&Array.isArray(value.plan.meals))return value;}}catch(_){}
 return null;
}
function write(userId,day,hash,result){
 if(!result||!result.plan||!Array.isArray(result.plan.meals))return false;
 try{const q=sql(),now=new Date();q.put.run(userId,day,hash,JSON.stringify(result),now.toISOString());
 q.prune.run(userId,userId);return true;
 }catch(_){return false;} // persistence failure must not alter an already computed plan
}
module.exports={version,digest,read,write};
