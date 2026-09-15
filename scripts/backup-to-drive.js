'use strict';
// [BACKUP-DRIVE] رفع ملف نسخة احتياطية (dump.gz) لمجلد Google Drive —
// صفر مكتبات خارجية: JWT بخدمة الحساب (crypto) ثم رفع multipart (https).
// المتغيرات المطلوبة (GitHub Secrets):
//   GCP_SA_JSON     = محتوى JSON لمفتاح Service Account (له صلاحية على المجلد)
//   DRIVE_FOLDER_ID = معرف مجلد الوجهة في درايف (من رابط المجلد)
// الاستخدام: node scripts/backup-to-drive.js /path/to/elforma-YYYY-MM-DD.sql.gz
const crypto = require('crypto');
const fs = require('fs');
const https = require('https');

function postJson(urlStr, headers, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlStr);
    const req = https.request({
      method: 'POST', hostname: u.hostname, path: u.pathname + u.search, headers,
    }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try { resolve({ status: res.statusCode, json: JSON.parse(data || '{}') }); }
        catch (_) { resolve({ status: res.statusCode, json: {}, raw: data.slice(0, 300) }); }
      });
    });
    req.on('error', reject);
    req.setTimeout(60000, () => req.destroy(new Error('timeout')));
    req.end(body);
  });
}

function postMultipart(urlStr, token, meta, fileBuf, filename, mime) {
  return new Promise((resolve, reject) => {
    const boundary = 'ef_backup_' + Date.now();
    const head = Buffer.from(
      '--' + boundary + '\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n' +
      JSON.stringify(meta) + '\r\n' +
      '--' + boundary + '\r\nContent-Type: ' + mime + '\r\n\r\n'
    );
    const tail = Buffer.from('\r\n--' + boundary + '--\r\n');
    const body = Buffer.concat([head, fileBuf, tail]);
    const u = new URL(urlStr);
    const req = https.request({
      method: 'POST', hostname: u.hostname, path: u.pathname + u.search,
      headers: {
        authorization: 'Bearer ' + token,
        'content-type': 'multipart/related; boundary=' + boundary,
        'content-length': body.length,
      },
    }, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try { resolve({ status: res.statusCode, json: JSON.parse(data || '{}') }); }
        catch (_) { resolve({ status: res.statusCode, json: {}, raw: data.slice(0, 300) }); }
      });
    });
    req.on('error', reject);
    req.setTimeout(120000, () => req.destroy(new Error('timeout')));
    req.write(body);
    req.end();
  });
}

async function main() {
  const file = process.argv[2];
  if (!file || !fs.existsSync(file)) throw new Error('backup_file_missing');
  const sa = JSON.parse(process.env.GCP_SA_JSON || '{}');
  const folderId = process.env.DRIVE_FOLDER_ID;
  if (!sa.client_email || !sa.private_key) throw new Error('GCP_SA_JSON_invalid');
  if (!folderId) throw new Error('DRIVE_FOLDER_ID_missing');

  // 1) JWT بخدمة الحساب → access token (ساعة)
  const now = Math.floor(Date.now() / 1000);
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const unsigned = b64({ alg: 'RS256', typ: 'JWT' }) + '.' + b64({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/drive.file',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
  });
  const signature = crypto.sign('RSA-SHA256', Buffer.from(unsigned), sa.private_key).toString('base64url');
  const jwt = unsigned + '.' + signature;

  const tokenRes = await postJson(
    'https://oauth2.googleapis.com/token',
    { 'content-type': 'application/x-www-form-urlencoded' },
    'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=' + jwt
  );
  if (!tokenRes.json.access_token) throw new Error('token_failed:' + JSON.stringify(tokenRes.json).slice(0, 200));

  // 2) الرفع للمجلد
  const buf = fs.readFileSync(file);
  const name = require('path').basename(file);
  const up = await postMultipart(
    'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,size,createdTime',
    tokenRes.json.access_token,
    { name: name, parents: [folderId] },
    buf, name, 'application/gzip'
  );
  if (up.status >= 300) throw new Error('upload_failed:' + up.status + ' ' + JSON.stringify(up.json).slice(0, 200));
  console.log('[backup-drive] ✅ اترفعت:', up.json.name, '| id:', up.json.id, '| حجم:', up.json.size, 'بايت');
}

main().catch((e) => { console.error('[backup-drive] ❌', e.message); process.exit(1); });
