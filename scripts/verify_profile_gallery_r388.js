#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const {versionAtLeast,revisionAtLeast}=require('./assert_compatible_release');
const html = fs.readFileSync(path.join(root, 'web/index.html'), 'utf8');
const source = JSON.parse(fs.readFileSync(path.join(root, 'web/client-source.json'), 'utf8'));
assert(versionAtLeast(source.sourceVersion, '9.6.360'));
assert(revisionAtLeast(source.sourceRevision, 388));
assert(versionAtLeast(fs.readFileSync(path.join(root, 'PACKAGE_VERSION.txt'), 'utf8').trim(), '0.1.196'));
for (const marker of [
  'id="publicProfileHeaderStorage"',
  'public-profile-gallery-helena',
  'title.textContent = helenaProjectFallbackName(item);',
  'async function readHelenaProjectCardMetadata(file)',
  'function readLeadingHelenaProjectCardEntries(buffer)',
  'headers: { Range: `bytes=0-${maxPrefixBytes - 1}` }',
  'if (opened && viewedIdentityId && state.activeProfileViewIdentityId === viewedIdentityId) closePublicProfile();',
  'const committedAndReserved = usedBytes + reservedBytes;',
  'buyMore.disabled = true;',
  "quotaBytes > 0 && percent >= 80 ? 'near' : 'normal'",
  "storageCard.dataset.level = quotaBytes > 0 && committedAndReserved >= quotaBytes ? 'full'",
  'state.publicProfileGalleryObserver?.disconnect();',
]) assert(html.includes(marker), `Missing synchronized gallery/header feature: ${marker}`);
console.log('Client r388 public-profile gallery, embedded Helena artwork previews, storage thresholds and successful overlay handoff passed.');
