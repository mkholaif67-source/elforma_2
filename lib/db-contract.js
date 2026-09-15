'use strict';

// Runtime contract shared by every supported database adapter. The product
// relies on the synchronous better-sqlite3-style API and SQLite SQL semantics.
// We prove those capabilities at boot instead of assuming that a configured
// server/database behaves like the local development database.
function verifyDatabaseContract(db) {
  if (!db || typeof db.exec !== 'function' || typeof db.prepare !== 'function') {
    throw new Error('database_contract_failed: synchronous exec/prepare API is required');
  }

  const id = 'boot-' + process.pid + '-' + Date.now() + '-' + Math.random().toString(36).slice(2, 8);
  let insert;
  let read;
  let deleted;
  try {
    db.exec(
      'CREATE TABLE IF NOT EXISTS _ef_database_probe (' +
      'id TEXT PRIMARY KEY, plan TEXT NOT NULL, status TEXT NOT NULL, updated_at TEXT NOT NULL)'
    );

    insert = db.prepare(
      'INSERT INTO _ef_database_probe (id, plan, status, updated_at) VALUES (?, ?, ?, ?) ' +
      'ON CONFLICT(id) DO UPDATE SET plan = excluded.plan, status = excluded.status, updated_at = excluded.updated_at ' +
      'RETURNING plan AS subscription_plan, status'
    ).get(id, 'probe_pro', 'active', new Date().toISOString());
    if (!insert || insert.subscription_plan !== 'probe_pro' || insert.status !== 'active') {
      throw new Error('insert_returning_shape');
    }

    read = db.prepare(
      'SELECT plan AS subscription_plan, status FROM _ef_database_probe WHERE id = ?'
    ).get(id);
    if (!read || read.subscription_plan !== 'probe_pro' || read.status !== 'active') {
      throw new Error('read_after_write');
    }

    deleted = db.prepare(
      'DELETE FROM _ef_database_probe WHERE id = ? RETURNING id AS deleted_id'
    ).get(id);
    if (!deleted || deleted.deleted_id !== id) {
      throw new Error('delete_returning_shape');
    }

    return Object.freeze({
      verified: true,
      api: 'sync-sqlite',
      dialect: 'sqlite',
      upsert: true,
      returning: true,
      aliasedRows: true,
      checkedAt: new Date().toISOString(),
    });
  } catch (error) {
    try { db.prepare('DELETE FROM _ef_database_probe WHERE id = ?').run(id); } catch (_) {}
    const detail = error && error.message ? error.message : String(error);
    throw new Error('database_contract_failed: ' + detail);
  }
}

module.exports = { verifyDatabaseContract };
