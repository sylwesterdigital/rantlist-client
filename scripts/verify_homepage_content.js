#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const file = path.join(root, 'homepage', 'content.json');

function fail(message) {
  console.error(`Homepage content verification failed: ${message}`);
  process.exit(1);
}

let payload;
try {
  payload = JSON.parse(fs.readFileSync(file, 'utf8'));
} catch (error) {
  fail(`content.json is not valid JSON (${error.message})`);
}

if (!payload || payload.schema !== 1) fail('schema must be 1');
const showcase = payload.showcase;
if (!showcase || typeof showcase !== 'object') fail('showcase object is required');
if (typeof showcase.enabled !== 'boolean') fail('showcase.enabled must be boolean');
for (const field of ['eyebrow', 'heading', 'description']) {
  if (typeof showcase[field] !== 'string' || !showcase[field].trim()) fail(`showcase.${field} must be non-empty text`);
  if (showcase[field].length > 240) fail(`showcase.${field} is too long`);
}
if (!Array.isArray(showcase.videos)) fail('showcase.videos must be an array');
if (showcase.enabled && showcase.videos.length < 1) fail('enabled showcase needs at least one video');
if (showcase.videos.length > 24) fail('showcase supports at most 24 videos');

showcase.videos.forEach((item, index) => {
  if (!item || typeof item !== 'object') fail(`video ${index + 1} must be an object`);
  if (typeof item.title !== 'string' || !item.title.trim()) fail(`video ${index + 1} title is required`);
  if (item.title.length > 120) fail(`video ${index + 1} title is too long`);
  let url;
  try { url = new URL(String(item.hls || '')); } catch (_) { fail(`video ${index + 1} hls URL is invalid`); }
  if (url.protocol !== 'https:') fail(`video ${index + 1} hls URL must use https`);
  if (!url.pathname.toLowerCase().endsWith('.m3u8')) fail(`video ${index + 1} hls URL must end in .m3u8`);
  if (item.poster !== undefined && item.poster !== '') {
    let poster;
    try { poster = new URL(String(item.poster)); } catch (_) { fail(`video ${index + 1} poster URL is invalid`); }
    if (poster.protocol !== 'https:') fail(`video ${index + 1} poster URL must use https`);
  }
});

const page = fs.readFileSync(path.join(root, 'homepage', 'index.html'), 'utf8');
const js = fs.readFileSync(path.join(root, 'homepage', 'showcase.js'), 'utf8');
if (!page.includes('id="showcase"')) fail('homepage carousel container is missing');
if (!page.includes('./showcase.js')) fail('homepage does not load showcase.js');
if (!page.includes('hls.js@')) fail('homepage does not load the pinned HLS.js fallback');
if (!page.includes('./assets/rantlist-app-icon.png')) fail('homepage does not use the app icon asset');
if (!page.includes('__LATEST_VERSION__')) fail('homepage release version placeholder is missing');
if (!js.includes("fetch('./content.json'")) fail('showcase.js does not load homepage/content.json');
if (!js.includes('window.Hls')) fail('showcase.js does not contain HLS.js fallback handling');
if (!js.includes("event.key === 'ArrowLeft'")) fail('carousel keyboard navigation is missing');

console.log(`Rantlist homepage content verification passed (${showcase.videos.length} video${showcase.videos.length === 1 ? '' : 's'}).`);
