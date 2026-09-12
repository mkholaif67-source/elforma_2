'use strict';
// Deduplicate deterministic SELECTs only inside an explicitly enabled request.
// Not an inter-request/user cache. A write invalidates the current read set.
const { AsyncLocalStorage } = require('node:async_hooks');
const storage = new AsyncLocalStorage();
function withRequestReads(fn) {
  return storage.run({ reads: new Map(), hits: 0, queries: 0, sqlMs: 0 }, fn);
}
function stats() {
  const s = storage.getStore();
  return s ? { queries: s.queries, hits: s.hits, sqlMs: Math.round(s.sqlMs * 100) / 100 } : null;
}
function wrapDatabase(client) {
  const statements = new WeakMap();
  return new Proxy(client, {
    get(target, prop) {
      if (prop === 'prepare') return function (sql) {
        const stmt = target.prepare(sql);
        if (statements.has(stmt)) return statements.get(stmt);
        // Do not cache SQL clock/random functions or RETURNING mutations.
        const deterministic = /^\s*SELECT\b/i.test(sql) &&
          !/\b(random|randomblob|changes|last_insert_rowid|current_timestamp|current_time|current_date|datetime|julianday|unixepoch|strftime)\b/i.test(sql);
        const proxy = new Proxy(stmt, { get(st, method) {
          const original = st[method];
          if (typeof original !== 'function') return original;
          if (!['get', 'all', 'run', 'iterate'].includes(method)) return original.bind(st);
          return function (...params) {
            const ctx = storage.getStore();
            if (!ctx) return original.apply(st, params);
            const read = deterministic && (method === 'get' || method === 'all');
            if (!/^\s*SELECT\b/i.test(sql)) ctx.reads.clear();
            const key = read ? JSON.stringify([sql, method, params], (_, v) =>
              typeof v === 'bigint' ? { $bigint: String(v) } : v) : null;
            if (read && process.env.EF_REQUEST_READ_CACHE !== '0' && ctx.reads.has(key)) {
              ctx.hits++;
              return structuredClone(ctx.reads.get(key));
            }
            const start = performance.now();
            ctx.queries++;
            try {
              const value = original.apply(st, params);
              if (read && process.env.EF_REQUEST_READ_CACHE !== '0' && ctx.reads.size < 256) {
                ctx.reads.set(key, structuredClone(value));
              }
              return value;
            } finally { ctx.sqlMs += performance.now() - start; }
          };
        }});
        statements.set(stmt, proxy);
        return proxy;
      };
      if (prop === 'exec') return function (...args) {
        storage.getStore()?.reads.clear();
        return target.exec(...args);
      };
      const value = target[prop];
      return typeof value === 'function' ? value.bind(target) : value;
    },
  });
}
module.exports = { withRequestReads, wrapDatabase, stats };
