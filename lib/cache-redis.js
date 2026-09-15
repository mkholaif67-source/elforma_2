'use strict';
// Synchronous L1 cache + OPTIONAL Redis invalidation bus, not a fake L2.
// No KEYS scan, startup warm-up or background copies of private plans.
// Cross-instance pub/sub is best-effort; disconnected instances clear L1 on
// reconnect. Do not claim strict distributed cache coherence from this alone.
const { createCache } = require('./cache');
const CHANNEL = 'ef:invalidate:v2';
const origin = require('node:crypto').randomUUID();
const caches = new Map();
let redis = null, subscriber = null;
const url = process.env.REDIS_URL || '';
if (url) {
  try {
    const Redis = require('ioredis');
    const options = { lazyConnect: true, enableOfflineQueue: false,
      maxRetriesPerRequest: 1, connectTimeout: 1500,
      retryStrategy: times => Math.min(times * 1000, 10000) };
    redis = new Redis(url, options);
    subscriber = new Redis(url, options);
    redis.on('error', () => {});
    subscriber.on('error', () => {});
    subscriber.on('ready', () => {
      for (const cache of caches.values()) cache.clear();
      subscriber.subscribe(CHANNEL).catch(() => {});
    });
    subscriber.on('message', (channel, raw) => {
      if (channel !== CHANNEL) return;
      try {
        const msg = JSON.parse(raw);
        if (msg.origin === origin) return;
        const cache = caches.get(msg.name);
        if (!cache) return;
        if (msg.clear === true) cache.clear();
        else if (typeof msg.key === 'string') cache.del(msg.key);
        else if (typeof msg.prefix === 'string') cache.invalidatePrefix(msg.prefix);
      } catch (_) {}
    });
    redis.connect().catch(() => {});
    subscriber.connect().catch(() => {});
  } catch (_) {
    console.warn('[cache] Redis unavailable; using bounded local cache');
  }
}
function broadcast(name, action) {
  if (redis?.status === 'ready') {
    redis.publish(CHANNEL, JSON.stringify({ name, origin, ...action })).catch(() => {});
  }
}
function createRedisCache(options, name = 'ef') {
  const local = createCache(options);
  caches.set(name, local);
  return {
    get: local.get,
    set: local.set,
    del(key) { const n = local.del(key); broadcast(name, { key }); return n; },
    invalidatePrefix(prefix) {
      const n = local.invalidatePrefix(prefix); broadcast(name, { prefix }); return n;
    },
    clear() { local.clear(); broadcast(name, { clear: true }); },
    stats: local.stats,
  };
}
module.exports = {
  createRedisCache,
  nutritionCache: createRedisCache({ max: 800, ttl: 90000 }, 'np'),
  catalogueCache: createRedisCache({ max: 64, ttl: 600000 }, 'cat'),
  redisEnabled: Boolean(redis),
};
