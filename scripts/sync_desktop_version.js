#!/usr/bin/env node
'use strict';
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const version = fs.readFileSync(path.join(root, 'VERSION.txt'), 'utf8').trim();
if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error(`Invalid VERSION.txt: ${version}`);
const file = path.join(root, 'desktop', 'package.json');
if (!fs.existsSync(file)) process.exit(0);
const pkg = JSON.parse(fs.readFileSync(file, 'utf8'));
pkg.version = version;
fs.writeFileSync(file, `${JSON.stringify(pkg, null, 2)}\n`);
console.log(`Desktop package version synchronized to ${version}.`);
