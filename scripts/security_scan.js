#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const root = path.resolve(process.argv[2] || '.');
const ignoredDirs = new Set(['.git', '.macos-build', 'release', 'node_modules', '__pycache__']);
const forbiddenBasenames = new Set([
  'server.js', 'deploy.sh', 'request-security.js', '.env',
  'id_rsa', 'id_ed25519', 'authorized_keys'
]);
const forbiddenFilePatterns = [
  /^\.env\./,
  /\.(?:pem|p12|pfx|key)$/i,
  /^nginx-.*\.conf$/i,
];
const textExtensions = new Set([
  '.html','.htm','.js','.mjs','.cjs','.json','.css','.svg','.md','.txt','.sh',
  '.swift','.plist','.yml','.yaml','.xml','.toml','.ini','.conf','.py','.rb'
]);

const checks = [
  ['Stripe secret key', /sk_(?:live|test)_[A-Za-z0-9]+/g],
  ['Stripe restricted key', /rk_(?:live|test)_[A-Za-z0-9]+/g],
  ['Stripe webhook secret', /whsec_[A-Za-z0-9]+/g],
  ['Stripe publishable key', /pk_(?:live|test)_[A-Za-z0-9]+/g],
  ['Stripe Buy Button id', /buy_btn_[A-Za-z0-9]+/g],
  ['GitHub classic token', /gh[pousr]_[A-Za-z0-9]{20,}/g],
  ['GitHub fine-grained token', /github_pat_[A-Za-z0-9_]{20,}/g],
  ['Slack token', /xox[baprs]-[A-Za-z0-9-]{10,}/g],
  ['AWS access key', /AKIA[0-9A-Z]{16}/g],
  ['Google API key', /AIza[0-9A-Za-z_-]{30,}/g],
  ['Private key block', /-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/g],
  ['Private IPv4 address', /\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})\b/g],
  ['Loopback host with explicit port', /\b(?:127\.0\.0\.1|localhost):\d{2,5}\b/gi],
  ['Production server filesystem path', /\/opt\/rantlist-chat\b/g],
  ['Nginx server filesystem path', /\/etc\/nginx\b/g],
];

let failures = [];

function walk(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    if (ignoredDirs.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    const rel = path.relative(root, full) || entry.name;
    if (entry.isDirectory()) {
      walk(full);
      continue;
    }
    if (!entry.isFile()) continue;

    if (forbiddenBasenames.has(entry.name) || forbiddenFilePatterns.some((rx) => rx.test(entry.name))) {
      failures.push(`${rel}: forbidden server/secret file name`);
      continue;
    }

    const ext = path.extname(entry.name).toLowerCase();
    if (!textExtensions.has(ext) && !['Makefile','LICENSE'].includes(entry.name)) continue;
    let body;
    try { body = fs.readFileSync(full, 'utf8'); } catch { continue; }
    for (const [label, rx] of checks) {
      rx.lastIndex = 0;
      const match = rx.exec(body);
      if (match) failures.push(`${rel}: ${label} (${match[0].slice(0, 28)}${match[0].length > 28 ? '…' : ''})`);
    }
  }
}

walk(root);
if (failures.length) {
  console.error('PUBLIC CLIENT SECURITY SCAN FAILED');
  for (const failure of failures) console.error(` - ${failure}`);
  process.exit(1);
}
console.log('Public client security scan passed: no forbidden server files, keys, private addresses or explicit local ports found.');
