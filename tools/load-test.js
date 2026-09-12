// اختبار حمل حقيقي للسيرفر — بدون مكتبات خارجية، ضد نسخة شغالة فعلًا
// بيقيس: مسار القراءة (bootstrap)، سلوك السيرفر تحت ضغط حساب الخطط، والكتابة المتزامنة
const { spawn } = require('child_process');
const http = require('http');

const PORT = 8390;

function req(method, path, body, cookie) {
  return new Promise((resolve) => {
    const t0 = process.hrtime.bigint();
    const data = body ? JSON.stringify(body) : null;
    const r = http.request({
      host: '127.0.0.1', port: PORT, path, method,
      headers: {
        'content-type': 'application/json',
        'x-tz-offset': '180',
        ...(cookie ? { cookie } : {}),
        ...(data ? { 'content-length': Buffer.byteLength(data) } : {}),
      },
    }, (res) => {
      let n = 0;
      res.on('data', (c) => (n += c.length));
      res.on('end', () => resolve({ status: res.statusCode, ms: Number(process.hrtime.bigint() - t0) / 1e6, bytes: n, cookie: res.headers['set-cookie'] }));
    });
    r.on('error', () => resolve({ status: 0, ms: Number(process.hrtime.bigint() - t0) / 1e6, bytes: 0 }));
    r.setTimeout(45000, () => { r.destroy(); resolve({ status: -1, ms: 45000, bytes: 0 }); });
    if (data) r.write(data);
    r.end();
  });
}

async function pool(count, size, fn) {
  const results = new Array(count);
  let i = 0;
  await Promise.all(Array.from({ length: size }, async () => {
    while (i < count) { const k = i++; results[k] = await fn(k); }
  }));
  return results;
}

function report(name, rs, totalMs) {
  const ok = rs.filter((r) => r.status >= 200 && r.status < 300);
  const times = rs.map((r) => r.ms).sort((a, b) => a - b);
  const p = (q) => (times.length ? Math.round(times[Math.min(times.length - 1, Math.floor(q * times.length))] * 10) / 10 : 0);
  console.log(`${name}`);
  console.log(`   ناجح: ${ok.length}/${rs.length} | p50=${p(0.5)}ms | p95=${p(0.95)}ms | p99=${p(0.99)}ms | أقصى=${p(1)}ms | ${Math.round(rs.length / (totalMs / 1000))} طلب/ث`);
  const errs = {};
  rs.filter((r) => !(r.status >= 200 && r.status < 300)).forEach((r) => (errs[r.status] = (errs[r.status] || 0) + 1));
  if (Object.keys(errs).length) console.log('   غير ناجح:', JSON.stringify(errs));
}

async function main() {
  const child = spawn(process.execPath, ['--experimental-sqlite', 'server.js'], {
    cwd: '/data/elforma/ElForma',
    env: Object.assign({}, process.env, {
      EF_DATA_DIR: '/tmp/ef-load-' + Date.now(),
      EF_DATABASE_ENGINE: 'sqlite',
      EF_REQUIRE_DURABLE_DB: '0',
      EF_SECRET: 'loadtest-secret',
      PORT: String(PORT),
      EF_ENV: 'test',
      EF_LOG_REQUESTS: '0',
    }),
    stdio: 'ignore',
  });

  try {
    // استنى الإقلاع
    let up = false;
    for (let i = 0; i < 60; i++) {
      const h = await req('GET', '/api/health');
      if (h.status === 200) { up = true; break; }
      await new Promise((r) => setTimeout(r, 250));
    }
    if (!up) { console.log('السيرفر ماقامش'); return; }

    // مستخدم حقيقي
    const email = 'load' + Date.now() + '@gmail.com';
    const s = await req('POST', '/api/auth/signup', { email, password: 'supersecret123', name: 'Load' });
    const cookie = ((s.cookie && s.cookie[0]) || '').split(';')[0];
    console.log('تهيئة: signup=' + s.status + ' | جلسة=' + (cookie ? 'تمام' : 'مفقودة') + '\n');

    // ── A) مسار القراءة: 2000 bootstrap بتزامن 100 ──
    let t0 = Date.now();
    const reads = await pool(2000, 100, () => req('GET', '/api/mobile/bootstrap', null, cookie));
    report('A) 2000 قراءة bootstrap (تزامن 100)', reads, Date.now() - t0);

    // ── B) ضغط حساب خطط (أثقل عملية 631ms) + قراءة في نفس الوقت ──
    const heavyBody = { profile: { gender: 'male', age: 28, height: 180, weight: 112, activity: 1.55, goal: 'cut', selectedDiet: 'balanced', mealCount: 4 }, inputs: {} };
    t0 = Date.now();
    const [mixedReads, computes] = await Promise.all([
      pool(500, 50, () => req('GET', '/api/mobile/bootstrap', null, cookie)),
      pool(12, 12, () => req('POST', '/api/plan/compute', heavyBody, cookie)),
    ]);
    const totalB = Date.now() - t0;
    report('B1) 500 قراءة أثناء عاصفة حساب خطط', mixedReads, totalB);
    report('B2) 12 حساب خطة متزامن (حد الـ rate limit)', computes, totalB);

    // ── C) كتابة متزامنة: 200 حفظ وزن ──
    t0 = Date.now();
    const writes = await pool(200, 20, (k) => req('PUT', '/api/mobile/weight', { day: '2026-09-09', weight: 95 + (k % 20) * 0.1 }, cookie));
    report('C) 200 كتابة متزامنة (تزامن 20)', writes, Date.now() - t0);

    // ── D) مؤشرات التشغيل الجديدة ──
    const ops = await req('GET', '/api/admin/ops', null, cookie);
    console.log('\nD) /api/admin/ops لمستخدم عادي (لازم 403):', ops.status);
  } finally {
    child.kill('SIGKILL');
  }
}

main().catch((e) => { console.error('load test failed:', e); process.exit(1); });
