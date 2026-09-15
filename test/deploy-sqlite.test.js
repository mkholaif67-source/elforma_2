'use strict';
// [FIX-DEPLOY-SQLITE] حراسة الديبلوي: المشكلة اللي وقّعت Render كانت
// إن node:sqlite اتطلب من غير فلاج. الاختبار ده بيتأكد إن وسائل الحماية
// التلاتة موجودة: حارس الإقلاع، الفلاج في أمر التشغيل، والفلاج في البيئة.
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
let pass = 0, fail = 0;
function ok(name, cond) { if (cond) { pass++; console.log('  \u2713 ' + name); } else { fail++; console.log('  \u2717 ' + name); } }
const server = fs.readFileSync(path.join(root, 'server.js'), 'utf8');
const docker = fs.readFileSync(path.join(root, 'Dockerfile'), 'utf8');
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const render = fs.readFileSync(path.join(root, 'render.yaml'), 'utf8');
const guard = fs.readFileSync(path.join(root, 'lib', 'ensure-sqlite.js'), 'utf8');
ok('server.js requires the sqlite boot guard before lib/db',
  server.indexOf("require('./lib/ensure-sqlite')") >= 0 &&
  server.indexOf("require('./lib/ensure-sqlite')") < server.indexOf("require('./lib/db')"));
ok('boot guard re-execs with --experimental-sqlite', /--experimental-sqlite/.test(guard) && /spawnSync/.test(guard));
ok('boot guard cannot loop forever', /EF_SQLITE_REEXEC/.test(guard));
ok('Dockerfile CMD passes the flag', /--experimental-sqlite/.test(docker));
ok('Dockerfile exports NODE_OPTIONS with the flag', /NODE_OPTIONS=--experimental-sqlite/.test(docker));
ok('npm start passes the flag', /--experimental-sqlite/.test(String(pkg.scripts && pkg.scripts.start)));
ok('render.yaml sets NODE_OPTIONS', /NODE_OPTIONS/.test(render) && /--experimental-sqlite/.test(render));
ok('render.yaml declares the admin email', /EF_ADMIN_EMAILS/.test(render));
console.log(pass + ' passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
