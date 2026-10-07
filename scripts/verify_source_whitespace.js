#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const ignoredTop = new Set(['.git', 'web', 'release', '.macos-build', '.ios-build', '.android-build', '.quest-bubblewrap-build']);
const ignoredDirectoryNames = new Set(['build', '.gradle', 'node_modules']);
const textExtensions = new Set([
  '.md', '.txt', '.sh', '.js', '.json', '.swift', '.java', '.kt', '.kts',
  '.xml', '.plist', '.entitlements', '.pbxproj', '.properties', '.gradle',
  '.yml', '.yaml', '.html', '.css', '.svg', '.gitignore'
]);
const explicitTextNames = new Set(['VERSION.txt', 'PACKAGE_VERSION.txt', '.gitignore']);
const failures = [];

function shouldCheck(file) {
  const base = path.basename(file);
  return explicitTextNames.has(base) || textExtensions.has(path.extname(base).toLowerCase());
}

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (dir === root && ignoredTop.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isSymbolicLink()) continue;
    if (entry.isDirectory()) {
      if (ignoredDirectoryNames.has(entry.name)) continue;
      walk(full);
      continue;
    }
    if (!entry.isFile() || !shouldCheck(full)) continue;
    const data = fs.readFileSync(full);
    if (data.includes(0)) continue;
    const text = data.toString('utf8');
    const lines = text.split(/\n/);
    for (let i = 0; i < lines.length; i += 1) {
      const line = lines[i].replace(/\r$/, '');
      if (/[\t ]+$/.test(line)) {
        failures.push(`${path.relative(root, full)}:${i + 1}: trailing whitespace`);
      }
    }
  }
}

walk(root);
if (failures.length) {
  console.error(failures.join('\n'));
  console.error(`Source whitespace verification failed: ${failures.length} line(s).`);
  process.exit(1);
}
console.log('Source whitespace verification passed: non-web client source has no trailing whitespace.');
