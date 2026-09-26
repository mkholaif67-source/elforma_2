'use strict';
const assert = require('assert');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');

process.env.EF_DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'ef-admin-browser-'));
process.env.PORT = '0';
process.env.EF_ADMIN_SETUP_TOKEN = 'owner-browser-setup-2026-secure-token';

const server = require('../server');

function request(method, pathname, body, cookie) {
  return new Promise((resolve, reject) => {
    const payload = body == null ? null : JSON.stringify(body);
    const headers = {};
    if (payload) {
      headers['content-type'] = 'application/json';
      headers['content-length'] = Buffer.byteLength(payload);
    }
    if (cookie) headers.cookie = cookie;
    const req = http.request({
      host: '127.0.0.1', port: server.address().port,
      method, path: pathname, headers,
    }, res => {
      let raw = '';
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => {
        const setCookie = res.headers['set-cookie'] || [];
        const found = /ef_session=[^;]*/.exec(setCookie.join(';'));
        let json = null;
        try { json = JSON.parse(raw); } catch (_) {}
        resolve({ status: res.statusCode, raw, json, cookie: found && found[0] });
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

(async () => {
  await new Promise(resolve => server.listening ? resolve() : server.on('listening', resolve));
  const signup = await request('POST', '/api/auth/signup', {
    email: 'mokholaif7@gmail.com',
    password: 'Browser-owner-pass-2026',
    name: 'ElForma Owner',
  });
  assert.strictEqual(signup.status, 201);
  assert.ok(signup.cookie);

  const outsider = await request('POST', '/api/auth/signup', {
    email: 'not-admin-browser@gmail.com',
    password: 'Browser-outsider-pass-2026',
    name: 'Regular User',
  });
  const outsiderTry = await request('POST', '/api/admin/setup/verify', {
    token: process.env.EF_ADMIN_SETUP_TOKEN,
  }, outsider.cookie);
  assert.strictEqual(outsiderTry.status, 403);
  assert.strictEqual(outsiderTry.json.error, 'forbidden');

  const before = await request('GET', '/api/admin/whoami', null, signup.cookie);
  assert.strictEqual(before.status, 200);
  assert.strictEqual(before.json.adminEmail, true);
  assert.strictEqual(before.json.verified, false);
  assert.strictEqual(before.json.admin, false);

  const wrong = await request('POST', '/api/admin/setup/verify', {
    token: 'wrong-owner-browser-setup-token',
  }, signup.cookie);
  assert.strictEqual(wrong.status, 403);
  assert.strictEqual(wrong.json.error, 'invalid_setup_token');

  const activated = await request('POST', '/api/admin/setup/verify', {
    token: process.env.EF_ADMIN_SETUP_TOKEN,
  }, signup.cookie);
  assert.strictEqual(activated.status, 200);
  assert.strictEqual(activated.json.verified, true);

  const after = await request('GET', '/api/admin/whoami', null, signup.cookie);
  assert.strictEqual(after.status, 200);
  assert.strictEqual(after.json.admin, true);

  const panel = await request('GET', '/admin.html', null, signup.cookie);
  assert.strictEqual(panel.status, 200);
  assert.match(panel.raw, /لوحة التحكم/);

  const login = fs.readFileSync(path.join(__dirname, '../public/login.html'), 'utf8');
  assert.match(login, /\/api\/auth\/verify\/send/);
  assert.match(login, /\/api\/admin\/setup\/verify/);
  assert.match(login, /EF_ADMIN_SETUP_TOKEN/);

  const account = fs.readFileSync(path.join(__dirname, '../mobile/lib/screens/account_screen.dart'), 'utf8');
  assert.doesNotMatch(account, /final glow =/);
  assert.doesNotMatch(account, /SingleTickerProviderStateMixin/);

  console.log('admin-browser-setup: 16 passed, 0 failed');
  server.close(() => process.exit(0));
})().catch(error => {
  console.error(error);
  server.close(() => process.exit(1));
});
