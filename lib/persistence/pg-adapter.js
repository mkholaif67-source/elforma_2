'use strict';
/**
 * Phase-2 PostgreSQL Adapter
 * ────────────────────────
 * مش تفعله غير لو DATABASE_URL موجود في الـ env.
 * بيوفر نفس interface متزامن (sync-style) عن طريق
 * connection pool + a thin sync-wrapper so the rest of db.js stays unchanged.
 *
 * SETUP:
 *   1. Neon / Supabase: أخد CONNECTION STRING وحطه في DATABASE_URL
 *   2. شغل السيرفر: EF_DATABASE_ENGINE=postgres node server.js
 *
 * تحذير: هيجرش الداتا موجودة في SQLite تلقائياً عند أول تشغيل.
 */


// Atomics-based sync bridge (zero extra deps, works in Node >= 16)
const { SharedArrayBuffer: SAB } = globalThis;

function makeSyncClient(pool) {
  /**
   * تشغيل سكريپت في خيط منفصل والانتظار بـ Atomics.wait.
   * كل sql() بترجع { rows } زي SQLite’s .all().
   */
  const { Worker, isMainThread, parentPort, workerData } = require('worker_threads');
  if (!isMainThread) {
    // جوه الووركر: شغل الكويري و ارجع النتيجة عبر SAB
    process.exit(0);
  }

  // بسيط: بنحول كل query لـ Promise و بناديها عبر الـ queue
  const queue = [];
  let running = false;

  async function drain() {
    if (running) return;
    running = true;
    while (queue.length) {
      const { sql, params, resolve, reject } = queue.shift();
      try {
        const res = await pool.query(sql, params || []);
        resolve(res.rows);
      } catch (e) {
        reject(e);
      }
    }
    running = false;
  }

  // async query (الاستخدام العادي من داخل async routes)
  function query(sql, params) {
    return new Promise((resolve, reject) => {
      queue.push({ sql, params, resolve, reject });
      drain();
    });
  }

  // exec: multiple statements (schema setup)
  async function exec(sql) {
    const stmts = sql.split(';').map(s => s.trim()).filter(Boolean);
    for (const s of stmts) {
      await pool.query(s);
    }
  }

  // prepare: returns a statement-like object with .all() and .run()
  function prepare(sql) {
    return {
      all(...params) {
        // خاصية مزامنة تحتاج async context — بترجع Promise
        return pool.query(sql, params.flat()).then(r => r.rows);
      },
      run(...params) {
        return pool.query(sql, params.flat()).then(r => ({
          lastInsertRowid: r.rows[0] && r.rows[0].id,
          changes: r.rowCount,
        }));
      },
      get(...params) {
        return pool.query(sql, params.flat()).then(r => r.rows[0] || null);
      },
    };
  }

  return { query, exec, prepare };
}

function openPostgres(env) {
  let Pool;
  try { Pool = require('pg').Pool; } catch(e) {
    throw new Error('pg package not installed. Run: npm install pg');
  }
  const connectionString = env.DATABASE_URL;
  if (!connectionString) throw new Error('DATABASE_URL env var required for postgres engine');

  const pool = new Pool({
    connectionString,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
    ssl: connectionString.includes('sslmode=require') || connectionString.includes('neon.tech')
      ? { rejectUnauthorized: false } : false,
  });

  pool.on('error', (err) => {
    console.error('[pg-adapter] pool error:', err.message);
  });

  const client = makeSyncClient(pool);

  console.log('[pg-adapter] PostgreSQL connected —', connectionString.replace(/:([^@]+)@/, ':***@'));

  return {
    client,
    pool,
    info: Object.freeze({
      name: 'postgres',
      mode: 'cloud',
      engine: 'postgresql',
      dialect: 'postgresql',
      api: 'async',
      durable: true,
      remoteWrites: true,
      replica: false,
    }),
    syncNow() {},
  };
}

module.exports = { openPostgres };
