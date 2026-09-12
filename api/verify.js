'use strict';
// /api/auth/* email flows: verify email, resend verification, forgot + reset password.
const db = require('../lib/db');
const auth = require('../lib/auth');
const mailer = require('../lib/mailer');
const cfg = require('../lib/config');
const { sendJson, readJsonBody, parseCookies, isEmail } = require('../lib/util');
const { rateLimit } = require('../lib/rateLimit');

const DEV = cfg.APP.env !== 'production';

function link(pathAndQuery) { return cfg.APP.base_url.replace(/\/$/, '') + pathAndQuery; }

// POST /api/auth/verify/send  (auth required) -> emails a fresh verification link
async function sendVerification(req, res, ip) {
  const user = auth.currentUser(parseCookies(req));
  if (!user) return sendJson(res, 401, { error: 'unauthenticated' });
  if (user.verified) return sendJson(res, 200, { ok: true, already: true });
  if (!rateLimit('verifysend:' + user.id, 5, 300000)) return sendJson(res, 429, { error: 'استنى شوية وحاول تاني' });
  const token = mailer.createToken(user.id, 'verify', 86400);
  const url = link('/verify-email.html?token=' + token);
  const delivery = mailer.sendVerify(user, url) || {};
  db.audit(user.id, 'verify_sent', ip);
  return sendJson(res, 200, Object.assign({ ok: true, sent: delivery.sent === true }, DEV ? { dev_link: url } : {}));
}

// POST /api/auth/verify { token } -> marks the account verified
async function verify(req, res, ip) {
  const b = await readJsonBody(req);
  const uid = mailer.consumeToken(String(b.token || ''), 'verify');
  if (!uid) return sendJson(res, 400, { error: 'invalid_or_expired' });
  db.db.prepare('UPDATE users SET verified = 1 WHERE id = ?').run(uid);
  db.audit(uid, 'verified', ip);
  return sendJson(res, 200, { ok: true });
}

// POST /api/auth/forgot { email } -> always 200 (no user enumeration)
async function forgot(req, res, ip) {
  if (!rateLimit('forgot:' + ip, 10, 300000)) return sendJson(res, 429, { error: 'محاولات كتيرة' });
  const b = await readJsonBody(req);
  const email = String(b.email || '').trim().toLowerCase();
  let devLink;
  if (isEmail(email)) {
    const user = db.userByEmail(email);
    if (user) {
      const token = mailer.createToken(user.id, 'reset', 3600);
      const url = link('/reset.html?token=' + token);
      mailer.sendReset(user, url);
      db.audit(user.id, 'reset_requested', ip);
      if (DEV) devLink = url;
    }
  }
  return sendJson(res, 200, Object.assign({ ok: true }, devLink ? { dev_link: devLink } : {}));
}

// POST /api/auth/reset { token, password } -> sets a new password
async function reset(req, res, ip) {
  const b = await readJsonBody(req);
  const pwProblem = auth.passwordProblem(b.password);
  if (pwProblem) return sendJson(res, 400, { error: pwProblem });
  const uid = mailer.consumeToken(String(b.token || ''), 'reset');
  if (!uid) return sendJson(res, 400, { error: 'invalid_or_expired' });
  const { hash, salt } = auth.hashPassword(b.password);
  db.db.prepare('UPDATE users SET pass_hash = ?, pass_salt = ?, token_version = token_version + 1 WHERE id = ?').run(hash, salt, uid);
  db.audit(uid, 'password_reset', ip);
  return sendJson(res, 200, { ok: true });
}

module.exports = { sendVerification, verify, forgot, reset, sendPhoneOtp, verifyPhoneOtp };

// تحقق الهاتف متوقف لحين ربط مزود SMS حقيقي؛ الكود القديم كان يقبل أي 6 أرقام.
async function sendPhoneOtp(req,res){const u=auth.currentUser(parseCookies(req));if(!u)return sendJson(res,401,{error:'unauthenticated'});return sendJson(res,503,{error:'تأكيد الهاتف غير متاح حاليا'});}
async function verifyPhoneOtp(req,res){const u=auth.currentUser(parseCookies(req));if(!u)return sendJson(res,401,{error:'unauthenticated'});return sendJson(res,503,{error:'تأكيد الهاتف غير متاح حاليا'});}
