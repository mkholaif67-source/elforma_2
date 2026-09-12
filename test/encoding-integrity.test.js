'use strict';
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const textExt = new Set(['.html','.js','.css','.json','.dart','.yaml','.yml','.md','.txt']);
const skip = new Set(['node_modules','.git','data']);
const bad = [];

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (skip.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) { walk(full); continue; }
    if (!textExt.has(path.extname(entry.name).toLowerCase())) continue;
    const text = fs.readFileSync(full, 'utf8');
    if (text.includes('\uFFFD')) bad.push(path.relative(root, full) + ': replacement character U+FFFD');
  }
}

walk(root);
assert.deepStrictEqual(bad, [], 'Corrupted UTF-8 source text:\n' + bad.join('\n'));
console.log('[encoding-integrity] PASS — zero U+FFFD characters in source/UI files');
