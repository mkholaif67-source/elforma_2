'use strict';
// Targeted regression guard, NOT a replacement for flutter analyze/test.
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const src=fs.readFileSync(path.join(__dirname,'../mobile/lib/api.dart'),'utf8');
const start=src.indexOf('Future<int> flushOfflineQueue()');
assert(start>=0);
const end=src.indexOf('// ----',start);
const block=src.slice(start,end);
assert.match(block,/final queueKey\s*=\s*_queueKey/,'Capture the account-scoped queue key before awaits');
assert.match(block,/raw\['ownerId'\]\s*!=\s*owner/,'Reject entries belonging to another account');
assert.match(block,/await\s+sp\.setString\(\s*queueKey\s*,\s*jsonEncode\(\s*queue\s*\)\s*\)\s*;/,'Pass both arguments inside setString, without an early closing parenthesis');
assert.doesNotMatch(block,/setString\(\s*queueKey\s*\)\s*,/,'The 1.0.25 compiler defect must not return');
console.log('PASS: queue-write source guard; Flutter analysis is still required');
