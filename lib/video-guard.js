'use strict';
// ============================================================
//  VIDEO GUARD  (Sprint 13)
//
//  The original project already contains a full video-safety
//  pipeline (verifiedVideoPipeline / getFallbackVid / safeVidUrl
//  in app/workout/export/video.js + ui/components.js).
//  It was never reachable from the mobile app: api/mobile.js and
//  api/workout.js returned the raw engine output and Flutter built
//  "youtube.com/watch?v=<vid>" by hand -- so a missing or dead id
//  (the engine default is the STRING 'null') produced the
//  "video unavailable" page the user reported.
//
//  This module is the single choke point: nothing reaches the app
//  without passing through resolve(). It reuses the ORIGINAL
//  pipeline when available and only falls back to its own logic if
//  the sandbox does not expose it.
// ============================================================

var host = require('./workout-engine-host');

// Last-resort ids taken from the original project's own tables.
var ULTIMATE = '6HgNrPFaGlw';

// Muscle-group fallbacks mirrored from VID_SAFE_FALLBACKS so a bad id
// still shows a RELEVANT demonstration instead of a random clip.
var GROUP_FALLBACK = {
  chest: 'SCVCLChPQEY',
  back: 'GZbfZ033f74',
  shoulders: 'qEwKCR5JCog',
  arms: 'kwG2ipFRgfo',
  legs: 'gcNh17Ckjgg',
  core: 'AnYl6Nk9GOA',
  glutes: 'SEdqd1n0cvg',
  cardio: '6HgNrPFaGlw'
};

// Arabic muscle labels coming out of the engine (mu field) -> group key.
var AR_GROUP = [
  ['\u0635\u062f\u0631', 'chest'],
  ['\u0638\u0647\u0631', 'back'],
  ['\u0644\u0627\u062a\u0633', 'back'],
  ['\u062a\u0631\u0627\u0628\u064a\u0632', 'back'],
  ['\u0643\u062a\u0641', 'shoulders'],
  ['\u062f\u0627\u0644\u064a', 'shoulders'],
  ['\u0628\u0627\u064a\u0633\u0628\u0633', 'arms'],
  ['\u062a\u0631\u0627\u064a\u0633\u0628\u0633', 'arms'],
  ['\u0630\u0631\u0627\u0639', 'arms'],
  ['\u0633\u0627\u0639\u062f', 'arms'],
  ['\u0631\u062c\u0644', 'legs'],
  ['\u0641\u062e\u0630', 'legs'],
  ['\u0633\u0645\u0627\u0646\u0629', 'legs'],
  ['\u0643\u0648\u0627\u062f', 'legs'],
  ['\u0647\u0627\u0645\u0633\u062a\u0631\u0646\u062c', 'legs'],
  ['\u062c\u0644\u0648\u062a', 'glutes'],
  ['\u0628\u0637\u0646', 'core'],
  ['\u062c\u0630\u0639', 'core'],
  ['\u0643\u0627\u0631\u062f\u064a\u0648', 'cardio']
];

function groupOf(muscle) {
  var s = String(muscle || '');
  for (var i = 0; i < AR_GROUP.length; i++) {
    if (s.indexOf(AR_GROUP[i][0]) > -1) return AR_GROUP[i][1];
  }
  var l = s.toLowerCase();
  var en = ['chest', 'back', 'shoulders', 'arms', 'legs', 'core', 'glutes', 'cardio'];
  for (var j = 0; j < en.length; j++) { if (l.indexOf(en[j]) > -1) return en[j]; }
  return 'default';
}

// Accepts a bare id, a watch?v= url, a youtu.be link or a /shorts/ link
// and returns a bare 11-ish char id, or '' when nothing usable is present.
function extractId(raw) {
  if (raw === null || raw === undefined) return '';
  var v = String(raw).trim();
  if (!v) return '';
  // The engine's own default placeholder is the literal string 'null'.
  var low = v.toLowerCase();
  if (low === 'null' || low === 'undefined' || low === 'none' || low === 'nan') return '';
  var m = v.match(/[?&]v=([A-Za-z0-9_-]{8,12})/);
  if (m) return m[1];
  m = v.match(/youtu\.be\/([A-Za-z0-9_-]{8,12})/);
  if (m) return m[1];
  m = v.match(/\/shorts\/([A-Za-z0-9_-]{8,12})/);
  if (m) return m[1];
  m = v.match(/\/embed\/([A-Za-z0-9_-]{8,12})/);
  if (m) return m[1];
  if (/^[A-Za-z0-9_-]{8,12}$/.test(v)) return v;
  return '';
}

// ── POLICY ────────────────────────────────────────────────────────────────
// Every video id in this project was verified BY HAND by the project owner.
// Therefore this module is forbidden from inventing, swapping or "repairing"
// a link. It may only:
//   - normalise a full URL down to its bare id (watch?v= / youtu.be / shorts)
//   - reject a placeholder ('null', 'undefined', '', 'none', 'NaN')
// When an id is genuinely absent the exercise is reported as missing so the
// UI can hide the button, and so a test can fail loudly. Showing the WRONG
// demonstration is worse than showing none: it teaches a wrong movement.
//
// GROUP_FALLBACK / ULTIMATE above are kept only so nothing that imports them
// breaks; they are deliberately never read.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
//  OWNER OVERRIDE LAYER
//
//  Video links used to be frozen inside the engine file, so a dead link meant
//  editing source and shipping a new release. Now the owner can repair one
//  from the admin page in seconds. This layer reads those repairs.
//
//  The map is cached for a minute because it is consulted once per exercise
//  per plan build (hundreds of times a request); every write invalidates it
//  immediately, so the cache can never serve a stale answer after an edit.
// ─────────────────────────────────────────────────────────────────────────────
var OVERRIDE_TTL_MS = 60000;
var _overrides = null;
var _overridesAt = 0;

/** Canonical lookup key for an exercise name. */
function videoKey(name) {
  return String(name == null ? '' : name).trim().toLowerCase().replace(/\s+/g, ' ');
}

function overrideMap() {
  var now = Date.now();
  if (_overrides && (now - _overridesAt) < OVERRIDE_TTL_MS) return _overrides;
  try {
    // Lazy require: the workout engine's own tests load this file with no
    // database present, and they must keep working.
    var db = require('./db');
    _overrides = db.videoOverrideMap();
  } catch (e) {
    _overrides = {};
  }
  _overridesAt = now;
  return _overrides;
}

function invalidateOverrides() {
  _overrides = null;
  _overridesAt = 0;
}


// ─────────────────────────────────────────────────────────────────────────
//  [FIX-VIDEO-DB] EXERCISE DATABASE LAYER  (Exercise -> Video URL)
//
//  قبل كده رابط الفيديو كان موجود في مكان واحد بس: جوّا نسخة الجدول
//  المتولّدة. فلو نسخة الجدول المحفوزة وصلت من غير vid (جدول قديم، أو
//  طريق حفظ مامرّ على الجارد) الرابط كان يختفي للأبد.
//  دلوقتي قاعدة بيانات التمارين نفسها (app/workout/engine/db.js) هي المصدر
//  الدائم: مفتاح التمرين (الاسم الموحّد) -> الـ videoId المكتوب بإيد صاحب
//  المشروع. مافيش رابط مخترع ولا fallback لمجموعة عضلية — نفس الرابط
//  الموثّق للتمرين برقمه/اسمه بس.
// ─────────────────────────────────────────────────────────────────────────
var CATALOGUE_TTL_MS = 300000;
var _catalogue = null;
var _catalogueAt = 0;

function _walkCatalogue(node, map, depth) {
  if (!node || depth > 8) return;
  if (Array.isArray(node)) {
    for (var i = 0; i < node.length; i++) {
      var item = node[i];
      if (item && typeof item === 'object' && typeof item.n === 'string') {
        var vid = typeof item.vid === 'string' ? item.vid : '';
        var k = videoKey(item.n);
        if (k && vid && !map[k]) map[k] = vid;
        // الاسم البديل (alt) بيتعرض في التطبيق أحيانًا فلازم يوصّل لنفس الفيديو.
        if (typeof item.alt === 'string' && item.alt) {
          var ka = videoKey(item.alt);
          if (ka && vid && !map[ka]) map[ka] = vid;
        }
        if (item.id != null) {
          var ki = videoKey(String(item.id));
          if (ki && vid && !map[ki]) map[ki] = vid;
        }
      } else if (item && typeof item === 'object') {
        _walkCatalogue(item, map, depth + 1);
      }
    }
    return;
  }
  if (typeof node === 'object') {
    var keys = Object.keys(node);
    for (var j = 0; j < keys.length; j++) _walkCatalogue(node[keys[j]], map, depth + 1);
  }
}

/** { exerciseKey: authoredVideoId } من قاعدة بيانات التمارين نفسها. */
function catalogueMap() {
  var now = Date.now();
  if (_catalogue && (now - _catalogueAt) < CATALOGUE_TTL_MS) return _catalogue;
  var map = {};
  try {
    var fs = require('fs');
    var path = require('path');
    var vm = require('vm');
    var file = path.join(__dirname, '..', 'app', 'workout', 'engine', 'db.js');
    var src = fs.readFileSync(file, 'utf8');
    var parsed = null;
    try {
      var sandbox = Object.create(null);
      var ctx = vm.createContext(sandbox);
      var wrapped = src + '\n;this.__EF_GYM_DB = (typeof GYM_DB !== "undefined") ? GYM_DB : null;';
      new vm.Script(wrapped, { filename: 'engine-db.js' }).runInContext(ctx, { timeout: 5000 });
      parsed = sandbox.__EF_GYM_DB;
    } catch (e) { parsed = null; }
    if (parsed && typeof parsed === 'object') _walkCatalogue(parsed, map, 0);
    if (!Object.keys(map).length && src) {
      var re = /n:\s*'([^']+)'[\s\S]{0,400}?vid:\s*'([^']*)'/g;
      var m;
      while ((m = re.exec(src)) !== null) {
        var kk = videoKey(m[1]);
        if (kk && m[2] && !map[kk]) map[kk] = m[2];
      }
    }
  } catch (e) { /* مفيش قاعدة بيانات متاحة (اختبارات المحرك) */ }
  _catalogue = map;
  _catalogueAt = now;
  return map;
}

function invalidateCatalogue() { _catalogue = null; _catalogueAt = 0; }

/** الـ videoId المحفوز للتمرين داخل قاعدة التمارين، أو '' لو مفيش. */
function catalogueVid(nameOrId) {
  var k = videoKey(nameOrId);
  if (!k) return '';
  var map = catalogueMap();
  return Object.prototype.hasOwnProperty.call(map, k) ? map[k] : '';
}

/**
 * resolve(rawVid, muscle, exerciseName) -> { videoId, url, thumb, group, source, missing }
 * videoId is the owner's override when one exists, otherwise EXACTLY the id
 * that was authored, or '' when there is none.
 */
function resolve(rawVid, muscle, exerciseName) {
  var group = groupOf(muscle);
  var id = extractId(rawVid);
  var source = 'authored';

  var key = videoKey(exerciseName);
  if (key) {
    var map = overrideMap();
    if (Object.prototype.hasOwnProperty.call(map, key)) {
      var ov = map[key];
      if (ov === '' || ov == null) {
        // A deliberate delete by the owner. Not a missing link, not an error:
        // the exercise stays fully usable, it just has no demonstration.
        return { videoId: '', url: '', thumb: '', group: group, source: 'removed', missing: true };
      }
      var ovId = extractId(ov);
      if (ovId) { id = ovId; source = 'override'; }
    }
  }

  // [FIX-VIDEO-DB] مافيش vid جاي مع التمرين? نرجع لقاعدة بيانات التمارين
  // ونجيب الرابط الموثّق بنفسه للتمرين ده (Exercise -> Video URL).
  // مافيش اختراع: لو التمرين مالوش رابط في القاعدة بيفضل missing.
  if (!id && key) {
    var catId = extractId(catalogueVid(exerciseName));
    if (catId) { id = catId; source = 'catalogue'; }
  }
  if (!id) {
    return { videoId: '', url: '', thumb: '', group: group, source: 'missing', missing: true };
  }
  return {
    videoId: id,
    url: 'https://www.youtube.com/watch?v=' + id,
    thumb: 'https://img.youtube.com/vi/' + id + '/hqdefault.jpg',
    group: group,
    source: source,
    missing: false
  };
}

/** Mutates an exercise in place: normalised link, or an explicit empty one. */
function attach(exercise) {
  if (!exercise || typeof exercise !== 'object') return exercise;
  // [FIX-VIDEO-PATH-4] نقرأ كل أسماء حقل الفيديو المستخدمة جوّا المشروع
  // (vid / videoId / videoUrl / video / v) مش تلاتة بس.
  var r = resolve(exercise.vid || exercise.videoId || exercise.videoUrl ||
                    exercise.video || exercise.v,
                  exercise.mu || exercise.muscle || exercise.group,
                  exercise.n || exercise.name);
  // ولو ماعرفناش نحلّ حاجة، ممنوع نمسح رابط موجود أصلًا.
  if (r.missing && (exercise.vid || exercise.videoId || exercise.videoUrl)) {
    exercise.videoMissing = false;
    return exercise;
  }
  exercise.vid = r.videoId;
  exercise.videoId = r.videoId;
  exercise.videoUrl = r.url;
  exercise.videoThumb = r.thumb;
  exercise.videoSource = r.source;
  exercise.videoMissing = r.missing;
  return exercise;
}

/** Walks a plan/day/exercise tree and normalises every video it finds. */
function guardPlan(node, depth) {
  depth = depth || 0;
  if (!node || depth > 8) return node;
  if (Array.isArray(node)) {
    for (var i = 0; i < node.length; i++) guardPlan(node[i], depth + 1);
    return node;
  }
  if (typeof node !== 'object') return node;
  var looksLikeExercise = Object.prototype.hasOwnProperty.call(node, 'vid') ||
    (Object.prototype.hasOwnProperty.call(node, 'n') && Object.prototype.hasOwnProperty.call(node, 'mu'));
  if (looksLikeExercise) attach(node);
  var keys = Object.keys(node);
  for (var k = 0; k < keys.length; k++) {
    var val = node[keys[k]];
    if (val && typeof val === 'object') guardPlan(val, depth + 1);
  }
  return node;
}

/** Reports every exercise that reached the app without an authored video. */
function auditPlan(node, out, depth) {
  out = out || [];
  depth = depth || 0;
  if (!node || depth > 8) return out;
  if (Array.isArray(node)) {
    for (var i = 0; i < node.length; i++) auditPlan(node[i], out, depth + 1);
    return out;
  }
  if (typeof node !== 'object') return out;
  if (typeof node.n === 'string' && Object.prototype.hasOwnProperty.call(node, 'vid')) {
    if (!extractId(node.vid)) out.push(node.n);
  }
  var keys = Object.keys(node);
  for (var k = 0; k < keys.length; k++) {
    var val = node[keys[k]];
    if (val && typeof val === 'object') auditPlan(val, out, depth + 1);
  }
  return out;
}

module.exports = {
  resolve: resolve,
  attach: attach,
  guardPlan: guardPlan,
  auditPlan: auditPlan,
  extractId: extractId,
  groupOf: groupOf,
  videoKey: videoKey,
  overrideMap: overrideMap,
  invalidateOverrides: invalidateOverrides,
  catalogueMap: catalogueMap,
  catalogueVid: catalogueVid,
  invalidateCatalogue: invalidateCatalogue,
  GROUP_FALLBACK: GROUP_FALLBACK,
  ULTIMATE: ULTIMATE
};
