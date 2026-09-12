'use strict';
const cfg = require('../lib/config');
const db = require('../lib/db');
const email = String(process.argv[2] || '').trim().toLowerCase();
if (!email || !cfg.isAdminEmail(email)) {
  console.error('رفض: اكتب إيميل أدمن موجود في EF_ADMIN_EMAILS.');
  process.exit(2);
}
const user = db.userByEmail(email);
if (!user) {
  console.error('الحساب غير موجود. سجله في التطبيق أولا بنفس الإيميل.');
  process.exit(3);
}
if (user.verified) {
  console.log('الحساب مؤكد بالفعل: ' + email);
  process.exit(0);
}
db.setVerified(user.id);
db.audit(user.id, 'admin_verified_from_server_console', 'server-console');
if (db.syncNow) db.syncNow();
const saved = db.userById(user.id);
if (!saved || !saved.verified) {
  console.error('فشل تأكيد الحساب.');
  process.exit(4);
}
console.log('تم تأكيد حساب الأدمن بأمان: ' + email);
