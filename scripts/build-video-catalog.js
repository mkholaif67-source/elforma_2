'use strict';
// ============================================================
//  build-video-catalog.js
//
//  بيولّد نسخة محلية (offline) من كتالوج فيديوهات التمارين
//  جوّا التطبيق — من المصدر الوحيد بالظبط:
//  app/workout/engine/db.js (الروابط اللي صاحب المشروع جمّعها بإيده).
//
//  POLICY: مافيش اختراع ولا تخمين ولا بحث تلقائي. بنسخ نفس
//  الروابط الموثّقة زي ما هي عشان التطبيق يعرفها حتى والسيرفر نايم.
//
//  بيتنفّذ وقت البناء (أو يدويًا): node scripts/build-video-catalog.js
// ============================================================
const fs = require('fs');
const path = require('path');
const guard = require('../lib/video-guard');

const OUT = path.join(__dirname, '..', 'mobile', 'assets', 'catalog', 'exercise_videos.json');

function main() {
  const map = guard.catalogueMap() || {};
  const keys = Object.keys(map).filter(function (k) { return k && map[k]; });
  if (!keys.length) {
    console.error('[build-video-catalog] \u0641\u0627\u0636\u064a! \u0645\u0627\u0642\u062f\u0631\u062a\u0634 \u0623\u0642\u0631\u0627 \u0623\u064a \u0631\u0648\u0627\u0628\u0637 \u0645\u0646 app/workout/engine/db.js');
    process.exit(1);
  }
  const payload = {
    // بصمة للتحقق إن النسخة المحلية متطابقة مع المصدر.
    _source: 'app/workout/engine/db.js',
    _generatedAt: new Date().toISOString(),
    _count: keys.length,
    // { exerciseKey(الاسم الموحّد): videoId }
    videos: keys.sort().reduce(function (acc, k) { acc[k] = map[k]; return acc; }, {}),
  };
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, JSON.stringify(payload, null, 2), 'utf8');
  console.log('[build-video-catalog] \u2713 \u0627\u062a\u0643\u062a\u0628 ' + keys.length + ' \u0641\u064a\u062f\u064a\u0648 \u0641\u064a ' + path.relative(path.join(__dirname, '..'), OUT));
}

main();
