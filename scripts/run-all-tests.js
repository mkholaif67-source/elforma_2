"use strict";
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');let failed=0;
for(const file of fs.readdirSync(path.join(root,'test')).filter(f=>f.endsWith('.test.js')).sort()){
 console.log('\n=== '+file+' ===');const result=spawnSync(process.execPath,[...process.execArgv,path.join(root,'test',file)],{cwd:root,stdio:'inherit',timeout:180000});
 if(result.status!==0){failed++;console.error('FAILED',file,result.error?.message||'');}
}
process.exitCode=failed?1:0;
