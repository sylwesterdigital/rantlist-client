#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

const sourceRoot = path.resolve(process.argv[2] || '');
const fieldArgIndex = process.argv.indexOf('--field');
const requestedField = fieldArgIndex >= 0 ? process.argv[fieldArgIndex + 1] : '';
if (!process.argv[2]) fail('Usage: source_release.js SOURCE_PROJECT [--field version|revision]');

const read = (file) => fs.readFileSync(path.join(sourceRoot, file), 'utf8');
const exists = (file) => fs.existsSync(path.join(sourceRoot, file));
const versions = [];

if (!exists('package.json')) fail(`Missing ${path.join(sourceRoot, 'package.json')}`);
let pkg;
try { pkg = JSON.parse(read('package.json')); } catch (error) { fail(`Invalid package.json: ${error.message}`); }
const packageVersion = String(pkg.version || '').trim();
if (!/^\d+\.\d+\.\d+$/.test(packageVersion)) fail(`package.json version must be x.y.z (found '${packageVersion || 'empty'}')`);
versions.push(['package.json', packageVersion]);

if (!exists('index.html')) fail(`Missing ${path.join(sourceRoot, 'index.html')}`);
const indexText = read('index.html');
const uiMatch = indexText.match(/<meta\s+name=["']chat-ui-version["']\s+content=["']([^"']+)["']/i)
  || indexText.match(/<meta\s+content=["']([^"']+)["']\s+name=["']chat-ui-version["']/i);
if (!uiMatch) fail('index.html is missing the chat-ui-version meta value.');
const uiVersion = uiMatch[1].trim();
versions.push(['index.html chat-ui-version', uiVersion]);

let revision = 'unknown';
let deploymentVersion = '';
if (exists('DEPLOYMENT_REVISION.json')) {
  let dep;
  try { dep = JSON.parse(read('DEPLOYMENT_REVISION.json')); } catch (error) { fail(`Invalid DEPLOYMENT_REVISION.json: ${error.message}`); }
  deploymentVersion = String(dep.applicationVersion || '').trim();
  revision = String(dep.revisionId || (dep.deploymentRevision != null ? `rantlist-deploy-r${dep.deploymentRevision}` : 'unknown')).trim() || 'unknown';
  if (deploymentVersion) versions.push(['DEPLOYMENT_REVISION.json applicationVersion', deploymentVersion]);
}

if (exists('server.js')) {
  const serverText = read('server.js');
  const serverMatch = serverText.match(/const\s+SERVER_VERSION\s*=.*?\|\|\s*['"]([^'"]+)['"]/);
  const fallbackMatch = serverText.match(/const\s+FALLBACK_UI_VERSION\s*=\s*['"]([^'"]+)['"]/);
  if (serverMatch) versions.push(['server.js SERVER_VERSION', serverMatch[1].trim()]);
  if (fallbackMatch) versions.push(['server.js FALLBACK_UI_VERSION', fallbackMatch[1].trim()]);
}

for (const [label, version] of versions) {
  if (version !== packageVersion) {
    fail(`Rantlist source version mismatch: package.json=${packageVersion}, ${label}=${version}. Fix stage/chat before syncing or publishing.`);
  }
}

const result = {
  version: packageVersion,
  revision,
  verifiedVersionSources: versions.map(([label]) => label),
  sourceRoot,
};

if (requestedField) {
  if (!(requestedField in result)) fail(`Unknown field '${requestedField}'.`);
  process.stdout.write(String(result[requestedField]));
} else {
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}
