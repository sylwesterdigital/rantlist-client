#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const source = JSON.parse(fs.readFileSync(path.join(root, 'web/client-source.json'), 'utf8'));
const web = fs.readFileSync(path.join(root, 'web/index.html'), 'utf8');
assert.equal(fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim(),'0.1.193');
assert.equal(source.sourceRevision, 'rantlist-deploy-r385');
assert.equal(source.sourceVersion, '9.6.357');
assert(web.includes('rantlist-public-client-snapshot'), 'the shared browser core must be sanitized');
for (const marker of [
  'function hlsPlaylistUrl(value)',
  '&& !hlsPlaylistUrl(text)',
  'function renderHlsVideoPreview(article, preview, streamUrl)',
  'function hlsPosterUrl(streamUrl)',
  "hls.on(HlsClass.Events.MANIFEST_PARSED, () => { void startPlayback(); });",
  "const hls = new HlsClass({ enableWorker: false });",
  "video.setAttribute('webkit-playsinline', '');",
  'function disposeHlsPreviewVideo(video)',
  'var(--media-preview-video-width, 720px)',
]) {
  assert(web.includes(marker), `Missing shared HLS browser code: ${marker}`);
}
console.log('Sanitized client HLS preview and paired server revision verification passed.');
