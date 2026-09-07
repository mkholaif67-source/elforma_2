'use strict';

// Durable migration ledger. Existing installations become the baseline once;
// every later schema change must get a higher immutable id instead of being a
// best-effort ALTER hidden in feature code.
const CURRENT_SCHEMA_VERSION = 2026090601;
const CURRENT_SCHEMA_NAME = 'database-adapter-baseline-v1.0.14';

function ensureMigrationLedger(db) {
  db.exec(
    'CREATE TABLE IF NOT EXISTS schema_migrations (' +
    'version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL)'
  );
  const newest = db.prepare(
    'SELECT version, name, applied_at FROM schema_migrations ORDER BY version DESC LIMIT 1'
  ).get();
  if (newest && Number(newest.version) > CURRENT_SCHEMA_VERSION) {
    throw new Error(
      'database_schema_newer_than_app:' + newest.version + '>' + CURRENT_SCHEMA_VERSION
    );
  }
  db.prepare(
    'INSERT OR IGNORE INTO schema_migrations (version, name, applied_at) VALUES (?, ?, ?)'
  ).run(CURRENT_SCHEMA_VERSION, CURRENT_SCHEMA_NAME, new Date().toISOString());
  const active = db.prepare(
    'SELECT version, name, applied_at FROM schema_migrations ORDER BY version DESC LIMIT 1'
  ).get();
  if (!active || Number(active.version) !== CURRENT_SCHEMA_VERSION) {
    throw new Error('database_schema_baseline_failed');
  }
  return Object.freeze({
    version: Number(active.version),
    name: active.name,
    appliedAt: active.applied_at,
  });
}

module.exports = {
  CURRENT_SCHEMA_VERSION,
  CURRENT_SCHEMA_NAME,
  ensureMigrationLedger,
};
