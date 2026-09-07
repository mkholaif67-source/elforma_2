'use strict';

// Single database-driver boundary. Business modules never choose or construct a
// driver themselves; they receive the same verified synchronous SQL surface
// from here. Today the supported adapters are local SQLite and Turso/libSQL.
// A future PostgreSQL adapter belongs behind this boundary, not inside auth,
// subscriptions, nutrition, workouts or the admin panel.
const fs = require('fs');

const SUPPORTED_ENGINES = Object.freeze(['auto', 'sqlite', 'turso']);

function requestedEngine(env) {
  const configured = String(env.EF_DATABASE_ENGINE || 'auto').trim().toLowerCase();
  if (!SUPPORTED_ENGINES.includes(configured)) {
    throw new Error(
      'unsupported_database_engine:' + configured +
      ' (supported: sqlite, turso; PostgreSQL needs its tested adapter)'
    );
  }
  if (configured === 'auto') return env.TURSO_DATABASE_URL ? 'turso' : 'sqlite';
  return configured;
}

function removeReplicaFiles(dbPath) {
  for (const suffix of ['', '-wal', '-shm', '-journal', '-info', '-client_wal_index']) {
    try { fs.rmSync(dbPath + suffix, { force: true }); } catch (_) {}
  }
}

function openLocalSQLite(dbPath, env) {
  let DatabaseSync;
  try {
    DatabaseSync = require('node:sqlite').DatabaseSync;
  } catch (error) {
    console.error('[db] node:sqlite is unavailable; run Node with --experimental-sqlite.');
    throw error;
  }
  const client = new DatabaseSync(dbPath);
  return {
    client,
    info: Object.freeze({
      name: 'sqlite',
      mode: 'local',
      engine: 'local-sqlite',
      dialect: 'sqlite',
      api: 'sync',
      durable: env.EF_STORAGE_DURABLE === '1',
      remoteWrites: false,
      replica: false,
      dbPath,
    }),
    syncNow() {},
  };
}

function openTurso(dbPath, env) {
  const url = String(env.TURSO_DATABASE_URL || '').trim();
  if (!url) throw new Error('turso_database_url_required');
  const mode = String(env.EF_TURSO_MODE || 'remote').trim().toLowerCase();
  if (mode !== 'remote' && mode !== 'replica') {
    throw new Error('unsupported_turso_mode:' + mode + ' (supported: remote, replica)');
  }

  if (!env.NODE_EXTRA_CA_CERTS) env.NODE_EXTRA_CA_CERTS = '/etc/ssl/certs/ca-certificates.crt';
  const LibsqlDatabase = require('libsql');
  let client;
  if (mode === 'replica') {
    const stale = fs.existsSync(dbPath + '-client_wal_index') && !fs.existsSync(dbPath);
    if (stale || env.EF_TURSO_RESET_REPLICA === '1') {
      removeReplicaFiles(dbPath);
      console.warn('[db] removed a stale Turso replica before synchronization.');
    }
    client = new LibsqlDatabase(dbPath, {
      syncUrl: url,
      authToken: env.TURSO_AUTH_TOKEN,
      syncInterval: Number(env.TURSO_SYNC_INTERVAL || 60),
    });
    try { client.sync(); }
    catch (error) { console.error('[db] Turso initial sync failed:', error && error.message); }
  } else {
    client = new LibsqlDatabase(url, { authToken: env.TURSO_AUTH_TOKEN });
  }

  return {
    client,
    info: Object.freeze({
      name: 'turso',
      mode,
      engine: 'turso-' + mode,
      dialect: 'sqlite',
      api: 'sync',
      durable: true,
      remoteWrites: true,
      replica: mode === 'replica',
      dbPath: mode === 'remote' ? null : dbPath,
    }),
    syncNow() {
      if (mode !== 'replica') return;
      try { client.sync(); }
      catch (error) { console.error('[db] Turso sync failed:', error && error.message); }
    },
  };
}

function openDatabaseAdapter(options) {
  const env = (options && options.env) || process.env;
  const dbPath = options && options.dbPath;
  if (!dbPath) throw new Error('database_path_required');
  const engine = requestedEngine(env);

  let adapter;
  try {
    adapter = engine === 'turso' ? openTurso(dbPath, env) : openLocalSQLite(dbPath, env);
  } catch (error) {
    const detail = error && error.message ? error.message : String(error);
    throw new Error('configured_database_unavailable:' + engine + ': ' + detail);
  }

  if (env.EF_REQUIRE_DURABLE_DB === '1' && !adapter.info.durable) {
    try { if (adapter.client && adapter.client.close) adapter.client.close(); } catch (_) {}
    throw new Error('durable_database_required:' + adapter.info.engine);
  }

  console.log('[db] adapter:', adapter.info.engine);
  return adapter;
}

module.exports = {
  SUPPORTED_ENGINES,
  requestedEngine,
  openDatabaseAdapter,
};
