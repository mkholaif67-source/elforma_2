'use strict';

// Optional durable receipt mirror. The database keeps only the receipt key;
// this module keeps the file upload independent from the database driver.
// EF_RECEIPTS_REMOTE_URL is a base URL or a URL containing {file}. It should
// point to private object storage or a small authenticated PUT/GET endpoint.
const fs = require('fs');
const path = require('path');

const REMOTE_URL = String(process.env.EF_RECEIPTS_REMOTE_URL || '').trim();
const REMOTE_TOKEN = String(process.env.EF_RECEIPTS_REMOTE_TOKEN || '').trim();
const TIMEOUT_MS = Math.max(1000, Number(process.env.EF_RECEIPTS_TIMEOUT_MS) || 15000);

function targetFor(file) {
  if (!REMOTE_URL) return null;
  const safe = path.basename(String(file || ''));
  if (!/^r_[\w.]+$/.test(safe)) return null;
  if (REMOTE_URL.includes('{file}')) return REMOTE_URL.replace('{file}', encodeURIComponent(safe));
  return (REMOTE_URL.endsWith('/') ? REMOTE_URL : REMOTE_URL + '/') + encodeURIComponent(safe);
}

function headers(contentType) {
  const out = { 'Content-Type': contentType || 'application/octet-stream' };
  if (REMOTE_TOKEN) out.Authorization = 'Bearer ' + REMOTE_TOKEN;
  return out;
}

async function put(filePath, fileName, contentType) {
  const target = targetFor(fileName);
  if (!target) return { ok: false, status: 'not_configured' };
  if (typeof fetch !== 'function') return { ok: false, status: 'fetch_unavailable' };
  const body = fs.readFileSync(filePath);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(target, {
      method: 'PUT',
      headers: Object.assign(headers(contentType), { 'Content-Length': String(body.length) }),
      body,
      signal: controller.signal,
    });
    return response.ok
      ? { ok: true, status: 'uploaded', target, bytes: body.length }
      : { ok: false, status: 'http_' + response.status, target };
  } catch (error) {
    return { ok: false, status: error && error.name === 'AbortError' ? 'timeout' : 'network_error', target };
  } finally {
    clearTimeout(timer);
  }
}

async function stream(fileName, res) {
  const target = targetFor(fileName);
  if (!target || typeof fetch !== 'function') return false;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(target, { method: 'GET', headers: headers(), signal: controller.signal });
    if (!response.ok || !response.body) return false;
    res.writeHead(200, {
      'Content-Type': response.headers.get('content-type') || 'application/octet-stream',
      'Content-Disposition': 'attachment; filename="' + path.basename(fileName) + '"',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; sandbox",
      'Cache-Control': 'no-store',
    });
    for await (const chunk of response.body) res.write(Buffer.from(chunk));
    res.end();
    return true;
  } catch (_) {
    return false;
  } finally {
    clearTimeout(timer);
  }
}

function configured() { return !!REMOTE_URL; }

module.exports = { put, stream, targetFor, configured };
