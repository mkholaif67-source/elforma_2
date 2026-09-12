'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const root = path.join(__dirname, '..');
const adapter = require('../lib/persistence/database-adapter');
const { verifyRepositoryContract, REQUIRED_METHODS } = require('../lib/persistence/repository-contract');
const { CURRENT_SCHEMA_VERSION } = require('../lib/persistence/migrations');
let pass = 0, fail = 0;
function test(name, fn) {
  try { fn(); pass++; console.log('  ✓ ' + name); }
  catch (error) { fail++; console.log('  ✗ ' + name + ' -> ' + error.message); }
}

console.log('\n[scaling-foundation]');

test('engine selection is explicit and deterministic', () => {
  assert.strictEqual(adapter.requestedEngine({}), 'sqlite');
  assert.strictEqual(adapter.requestedEngine({ TURSO_DATABASE_URL: 'libsql://example' }), 'turso');
  assert.strictEqual(adapter.requestedEngine({ EF_DATABASE_ENGINE: 'sqlite', TURSO_DATABASE_URL: 'libsql://example' }), 'sqlite');
  assert.strictEqual(adapter.requestedEngine({ EF_DATABASE_ENGINE: 'turso' }), 'turso');
});

test('unsupported databases fail instead of silently falling back', () => {
  assert.throws(
    () => adapter.requestedEngine({ EF_DATABASE_ENGINE: 'postgres' }),
    /unsupported_database_engine:postgres/
  );
});

test('repository contract detects a partial implementation', () => {
  assert(REQUIRED_METHODS.length >= 40);
  assert.throws(() => verifyRepositoryContract({}), /repository_contract_failed/);
});

function boot(extraEnv) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ef-scale-'));
  const code = "const d=require('./lib/db'); console.log('STORAGE='+JSON.stringify(d.storage));";
  const result = spawnSync(process.execPath, ['--experimental-sqlite', '-e', code], {
    cwd: root,
    env: Object.assign({}, process.env, {
      EF_DATA_DIR: dir,
      EF_DATABASE_ENGINE: 'sqlite',
      EF_ENV: 'test',
      EF_REQUIRE_DURABLE_DB: '0',
      EF_STORAGE_DURABLE: '0',
      TURSO_DATABASE_URL: '',
      TURSO_AUTH_TOKEN: '',
    }, extraEnv || {}),
    encoding: 'utf8',
  });
  fs.rmSync(dir, { recursive: true, force: true });
  return result;
}

test('SQLite adapter, migration ledger and repository boot together', () => {
  const result = boot();
  assert.strictEqual(result.status, 0, result.stderr || result.stdout);
  const line = result.stdout.split(/\r?\n/).find((v) => v.startsWith('STORAGE='));
  assert(line, result.stdout);
  const storage = JSON.parse(line.slice(8));
  assert.strictEqual(storage.adapter.name, 'sqlite');
  assert.strictEqual(storage.schema.version, CURRENT_SCHEMA_VERSION);
  assert.strictEqual(storage.repository.verified, true);
  assert.strictEqual(storage.contract.verified, true);
});

test('durability policy blocks ephemeral production storage', () => {
  const result = boot({ EF_ENV: 'production', EF_REQUIRE_DURABLE_DB: '1' });
  assert.notStrictEqual(result.status, 0);
  assert.match(result.stderr + result.stdout, /durable_database_required:local-sqlite/);
});

test('configured Turso cannot start without its URL', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ef-turso-'));
  const result = spawnSync(process.execPath, ['--experimental-sqlite', '-e', "require('./lib/db')"], {
    cwd: root,
    env: Object.assign({}, process.env, {
      EF_DATA_DIR: dir,
      EF_DATABASE_ENGINE: 'turso',
      TURSO_DATABASE_URL: '',
    }),
    encoding: 'utf8',
  });
  fs.rmSync(dir, { recursive: true, force: true });
  assert.notStrictEqual(result.status, 0);
  assert.match(result.stderr + result.stdout, /turso_database_url_required/);
});

test('Render pins Turso and requires durable storage', () => {
  const render = fs.readFileSync(path.join(root, 'render.yaml'), 'utf8');
  assert.match(render, /EF_DATABASE_ENGINE\s*\n\s*value: turso/);
  assert.match(render, /EF_REQUIRE_DURABLE_DB\s*\n\s*value: "1"/);
});

test('database construction stays in one adapter module', () => {
  const dbSource = fs.readFileSync(path.join(root, 'lib', 'db.js'), 'utf8');
  assert.match(dbSource, /openDatabaseAdapter/);
  assert.doesNotMatch(dbSource, /new LibsqlDatabase|require\('node:sqlite'\)/);
});

console.log(pass + ' passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
