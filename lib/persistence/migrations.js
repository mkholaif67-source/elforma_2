'use strict';

const CURRENT_SCHEMA_VERSION = 2026092401;
const CURRENT_SCHEMA_NAME = 'private-friend-challenges-v1';
const BASELINE_SCHEMA_VERSION = 2026090601;
const BASELINE_SCHEMA_NAME = 'database-adapter-baseline-v1.0.14';

function applyPrivateFriendChallenges(db) {
  db.exec(`
CREATE TABLE IF NOT EXISTS friend_challenges (
 id TEXT PRIMARY KEY,
 owner_id INTEGER NOT NULL,
 source_personal_id TEXT,
 title TEXT NOT NULL,
 description TEXT NOT NULL DEFAULT '',
 kind TEXT NOT NULL,
 metric TEXT NOT NULL,
 target REAL,
 unit TEXT NOT NULL DEFAULT '',
 scoring TEXT NOT NULL,
 exercise_key TEXT,
 start_date TEXT NOT NULL,
 end_date TEXT NOT NULL,
 weekdays_json TEXT NOT NULL,
 share_json TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'active',
 max_members INTEGER NOT NULL DEFAULT 20,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 FOREIGN KEY(owner_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_friend_challenges_owner ON friend_challenges(owner_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_friend_challenges_status ON friend_challenges(status, end_date);

CREATE TABLE IF NOT EXISTS friend_challenge_members (
 challenge_id TEXT NOT NULL,
 user_id INTEGER NOT NULL,
 role TEXT NOT NULL DEFAULT 'member',
 status TEXT NOT NULL DEFAULT 'active',
 display_name TEXT NOT NULL,
 invited_by INTEGER,
 joined_at TEXT NOT NULL,
 left_at TEXT,
 PRIMARY KEY(challenge_id, user_id),
 FOREIGN KEY(challenge_id) REFERENCES friend_challenges(id) ON DELETE CASCADE,
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(invited_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_friend_members_user ON friend_challenge_members(user_id, status);
CREATE INDEX IF NOT EXISTS idx_friend_members_challenge ON friend_challenge_members(challenge_id, status, joined_at);

CREATE TABLE IF NOT EXISTS friend_challenge_invites (
 id TEXT PRIMARY KEY,
 challenge_id TEXT NOT NULL,
 created_by INTEGER NOT NULL,
 code_hash TEXT NOT NULL UNIQUE,
 code_hint TEXT NOT NULL,
 expires_at TEXT NOT NULL,
 max_uses INTEGER NOT NULL DEFAULT 20,
 uses INTEGER NOT NULL DEFAULT 0,
 revoked_at TEXT,
 created_at TEXT NOT NULL,
 FOREIGN KEY(challenge_id) REFERENCES friend_challenges(id) ON DELETE CASCADE,
 FOREIGN KEY(created_by) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_friend_invites_challenge ON friend_challenge_invites(challenge_id, revoked_at, expires_at);

CREATE TABLE IF NOT EXISTS friend_challenge_join_requests (
 challenge_id TEXT NOT NULL,
 user_id INTEGER NOT NULL,
 invite_id TEXT NOT NULL,
 invited_by INTEGER NOT NULL,
 display_name TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'pending',
 requested_at TEXT NOT NULL,
 decided_at TEXT,
 decided_by INTEGER,
 PRIMARY KEY(challenge_id, user_id),
 FOREIGN KEY(challenge_id) REFERENCES friend_challenges(id) ON DELETE CASCADE,
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(invite_id) REFERENCES friend_challenge_invites(id) ON DELETE CASCADE,
 FOREIGN KEY(invited_by) REFERENCES users(id) ON DELETE CASCADE,
 FOREIGN KEY(decided_by) REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX IF NOT EXISTS idx_friend_requests_owner ON friend_challenge_join_requests(challenge_id, status, requested_at);

CREATE TABLE IF NOT EXISTS friend_challenge_entries (
 challenge_id TEXT NOT NULL,
 user_id INTEGER NOT NULL,
 day TEXT NOT NULL,
 value REAL NOT NULL,
 points REAL NOT NULL,
 source TEXT NOT NULL DEFAULT 'manual',
 note TEXT NOT NULL DEFAULT '',
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 PRIMARY KEY(challenge_id, user_id, day),
 FOREIGN KEY(challenge_id, user_id) REFERENCES friend_challenge_members(challenge_id, user_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_friend_entries_rank ON friend_challenge_entries(challenge_id, user_id, day);

CREATE TABLE IF NOT EXISTS friend_challenge_results (
 challenge_id TEXT NOT NULL,
 user_id INTEGER NOT NULL,
 rank INTEGER NOT NULL,
 score REAL NOT NULL,
 stats_json TEXT NOT NULL,
 finalized_at TEXT NOT NULL,
 PRIMARY KEY(challenge_id, user_id),
 FOREIGN KEY(challenge_id) REFERENCES friend_challenges(id) ON DELETE CASCADE,
 FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_friend_results_rank ON friend_challenge_results(challenge_id, rank);
  `);
}

function ensureMigrationLedger(db) {
  db.exec(
    'CREATE TABLE IF NOT EXISTS schema_migrations (' +
    'version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL)'
  );
  const newest = db.prepare(
    'SELECT version, name, applied_at FROM schema_migrations ORDER BY version DESC LIMIT 1'
  ).get();
  if (newest && Number(newest.version) > CURRENT_SCHEMA_VERSION) {
    throw new Error('database_schema_newer_than_app:' + newest.version + '>' + CURRENT_SCHEMA_VERSION);
  }
  if (!newest) {
    db.prepare('INSERT OR IGNORE INTO schema_migrations (version, name, applied_at) VALUES (?, ?, ?)')
      .run(BASELINE_SCHEMA_VERSION, BASELINE_SCHEMA_NAME, new Date().toISOString());
  }
  if (!newest || Number(newest.version) < CURRENT_SCHEMA_VERSION) {
    db.exec('BEGIN;');
    try {
      applyPrivateFriendChallenges(db);
      db.prepare('INSERT OR IGNORE INTO schema_migrations (version, name, applied_at) VALUES (?, ?, ?)')
        .run(CURRENT_SCHEMA_VERSION, CURRENT_SCHEMA_NAME, new Date().toISOString());
      db.exec('COMMIT;');
    } catch (error) {
      try { db.exec('ROLLBACK;'); } catch (_) {}
      throw error;
    }
  } else {
    applyPrivateFriendChallenges(db);
  }
  const active = db.prepare('SELECT version, name, applied_at FROM schema_migrations ORDER BY version DESC LIMIT 1').get();
  if (!active || Number(active.version) !== CURRENT_SCHEMA_VERSION) throw new Error('database_schema_migration_failed');
  return Object.freeze({version:Number(active.version), name:active.name, appliedAt:active.applied_at});
}

module.exports = {CURRENT_SCHEMA_VERSION, CURRENT_SCHEMA_NAME, ensureMigrationLedger};
