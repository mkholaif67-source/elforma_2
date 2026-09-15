'use strict';
// [FIX-DEPLOY-SQLITE] المشكلة اللي وقعت الديبلوي:
//   Error [ERR_UNKNOWN_BUILTIN_MODULE]: No such built-in module: node:sqlite
// node:sqlite لسّه experimental على Node 22، فمايشتغلش إلا بفلاج
// --experimental-sqlite. لو أي حاجة شغلت "node server.js" من غير الفلاج
// (أمر بداية متغير في لوحة Render، أو صورة قديمة، أو تشغيل يدوي)
// كان البروسيس بيموت وقت الإقلاع. الحل الجذري: مانعتمدش على الفلاج خالص —
// لو الموديول مش متاح، بنعيد تشغيل نفس البروسيس مرة واحدة بالفلاج.
// لازم يتنفّذ قبل أي require لـ lib/db.js.
try {
  require('node:sqlite');
} catch (err) {
  if (process.env.EF_SQLITE_REEXEC === '1') {
    console.error('[boot] node:sqlite مش متاح حتى بعد الفلاج — إصدار Node:', process.version);
  } else {
    const { spawnSync } = require('child_process');
    const args = ['--experimental-sqlite'].concat(process.argv.slice(1));
    console.error('[boot] مفيش فلاج --experimental-sqlite — بنعيد التشغيل بيه تلقائيا.');
    const r = spawnSync(process.execPath, args, {
      stdio: 'inherit',
      env: Object.assign({}, process.env, { EF_SQLITE_REEXEC: '1' }),
    });
    process.exit(typeof r.status === 'number' ? r.status : 1);
  }
}
