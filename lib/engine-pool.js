'use strict';
// Lazy, bounded worker pool. One task per worker; reject overload rather than
// retaining an unbounded queue. Idle workers do not keep tests/CLI tools alive.
const { Worker } = require('node:worker_threads');
const path = require('node:path');
const os = require('node:os');
function positive(value, fallback, max) {
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? Math.min(max, Math.floor(n)) : fallback;
}
const capacity = os.availableParallelism ? os.availableParallelism() : os.cpus().length;
const POOL_SIZE = positive(process.env.ENGINE_POOL_SIZE, Math.max(1, Math.min(2, capacity)), 8);
const TIMEOUT = positive(process.env.ENGINE_TASK_TIMEOUT_MS, 15000, 120000);
const MAX_QUEUE = positive(process.env.ENGINE_MAX_QUEUE, 32, 1024);
const file = path.join(__dirname, 'engine-worker-thread.js');
const slots = Array(POOL_SIZE).fill(null);
const queue = [];
let seq = 0;
let closed = false;

function finish(task, error, value) {
  if (!task || task.done) return;
  task.done = true;
  clearTimeout(task.timer);
  if (error) task.reject(error); else task.resolve(value);
}
function retire(slot, error) {
  if (slots[slot.index] !== slot) return;
  slots[slot.index] = null;
  finish(slot.task, error || new Error('worker_crashed'));
  slot.worker.terminate().catch(() => {});
  drain(); // only start replacements when there is actual pending work
}
function spawn(index) {
  const worker = new Worker(file);
  const slot = { index, worker, ready: false, task: null };
  slots[index] = slot;
  worker.on('message', msg => {
    if (slots[index] !== slot) return;
    if (msg.ready) slot.ready = true;
    else if (slot.task && slot.task.id === msg.id) {
      finish(slot.task, msg.ok ? null : new Error(msg.error || 'engine_failed'), msg.result);
      slot.task = null;
    }
    worker.unref();
    drain();
  });
  worker.on('error', () => retire(slot, new Error('worker_crashed')));
  worker.on('exit', () => retire(slot, new Error('worker_exited')));
}
function drain() {
  if (closed) return;
  while (queue[0]?.done) queue.shift();
  for (let index = 0; index < slots.length && queue.length; index++) {
    if (!slots[index]) { spawn(index); continue; }
    const slot = slots[index];
    if (!slot.ready || slot.task) continue;
    let task;
    do { task = queue.shift(); } while (task?.done && queue.length);
    if (!task || task.done) continue;
    slot.task = task;
    slot.worker.ref();
    try { slot.worker.postMessage(task.msg); }
    catch (_) { retire(slot, new Error('worker_send_failed')); }
  }
}
function dispatch(type, profile, inputs) {
  if (closed) return Promise.reject(new Error('engine_pool_closed'));
  if (queue.length >= MAX_QUEUE) return Promise.reject(new Error('engine_busy'));
  return new Promise((resolve, reject) => {
    const id = ++seq;
    const task = { id, msg: { id, type, profile, inputs }, resolve, reject, done: false };
    task.timer = setTimeout(() => {
      const i = queue.indexOf(task);
      if (i >= 0) queue.splice(i, 1);
      finish(task, new Error('engine_timeout'));
      const slot = slots.find(s => s?.task === task);
      if (slot) retire(slot, new Error('engine_timeout'));
      else drain();
    }, TIMEOUT);
    queue.push(task);
    drain();
  });
}
async function close() {
  closed = true;
  for (const task of queue.splice(0)) finish(task, new Error('engine_pool_closed'));
  const workers = slots.filter(Boolean);
  slots.fill(null);
  for (const slot of workers) finish(slot.task, new Error('engine_pool_closed'));
  await Promise.all(workers.map(slot => slot.worker.terminate()));
}
module.exports = {
  computeMealPlanAsync: (profile, inputs) => dispatch('plan', profile, inputs || {}),
  computeTargetsAsync: (profile, inputs) => dispatch('targets', profile, inputs || {}),
  poolSize: POOL_SIZE,
  stats: () => ({ poolSize: POOL_SIZE, started: slots.filter(Boolean).length,
    idle: slots.filter(s => s?.ready && !s.task).length,
    busy: slots.filter(s => s?.task).length, queued: queue.length,
    pending: queue.length + slots.filter(s => s?.task).length }),
  close,
};
