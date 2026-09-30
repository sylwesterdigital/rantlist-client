#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), 'utf8');
const web = read('web', 'index.html');
const android = read('mobile', 'android', 'app', 'src', 'main', 'java', 'fun', 'workwork', 'rantlist', 'MainActivity.java');
const manifest = read('mobile', 'android', 'app', 'src', 'main', 'AndroidManifest.xml');
const ios = read('mobile', 'ios', 'Rantlist', 'RantlistApp.swift');
const source = JSON.parse(read('web', 'client-source.json'));

const versionAtLeast = (actual, minimum) => {
  const a = String(actual || '').trim().split('.').map(Number);
  const b = String(minimum || '').trim().split('.').map(Number);
  if (a.length !== 3 || b.length !== 3 || a.some((n) => !Number.isInteger(n) || n < 0) || b.some((n) => !Number.isInteger(n) || n < 0)) return false;
  for (let i = 0; i < 3; i += 1) {
    if (a[i] > b[i]) return true;
    if (a[i] < b[i]) return false;
  }
  return true;
};
const revisionAtLeast = (actual, minimum) => {
  const match = String(actual || '').trim().match(/^rantlist-deploy-r(\d+)$/);
  return Boolean(match && Number(match[1]) >= minimum);
};

assert(versionAtLeast(read('PACKAGE_VERSION.txt').trim(), '0.1.237'),
  'client package predates the r449 native/mobile feature baseline');
assert(versionAtLeast(source.sourceVersion, '9.6.421'),
  'synchronized browser source predates the r449 feature baseline');
assert(revisionAtLeast(source.sourceRevision, 449),
  'synchronized deployment revision predates r449');

assert.match(web, /function sendReaction\(messageId, emoji\)[\s\S]*?const keepOpen = window\.matchMedia\('\(max-width: 850px\)'\)\.matches[\s\S]*?if \(!keepOpen\) closeReactionPickers\(\);/,
  'mobile reaction picker does not remain open for successive emoji');
assert.match(web, /function updateReactionUi\(messageId, reactions\)[\s\S]*?captureMessageScrollAnchor\(\)[\s\S]*?restoreMessageScrollAnchor\(anchor\)/,
  'mobile reaction updates do not preserve the timeline anchor');
assert.match(web, /messageListUserScrollRevision[\s\S]*?reactionOpenScrollRevision/,
  'reaction picker cannot distinguish user scroll from layout scroll');

assert.match(ios, /final class RantlistPDFViewController: UIViewController/,
  'iOS native PDF document controller missing');
assert.match(ios, /barButtonSystemItem: \.done/,
  'iOS PDF viewer has no Done control');
assert.match(ios, /navigationController\?\.dismiss\(animated: true\)/,
  'iOS PDF viewer Done action does not dismiss its document navigation controller');
assert.match(ios, /if isPDFPreviewURL\(url\), navigationAction\.targetFrame\?\.isMainFrame == true[\s\S]*?presentPDF\(url\)/,
  'iOS main-frame PDF navigation still replaces chat');
assert.match(ios, /func webView\(_ webView: WKWebView,[\s\S]*?createWebViewWith configuration:[\s\S]*?if isPDFPreviewURL\(url\)[\s\S]*?presentPDF\(url\)/,
  'iOS target=_blank PDF navigation still replaces chat');

assert.match(android, /Rantlist-Android/, 'Android native user-agent marker missing');
assert.match(android, /if \(isPdfPreviewUri\(uri\)\)[\s\S]*?openPdf\(uri/,
  'Android PDF links are not intercepted natively');
assert.match(android, /DownloadManager\.Request request = authenticatedDownloadRequest\(uri, userAgent, "application\/pdf"\)/,
  'Android PDF retrieval is not authenticated');
assert.match(android, /getUriForDownloadedFile\(id\)/,
  'Android PDF download is not converted into a shareable content URI');
assert.match(android, /FLAG_GRANT_READ_URI_PERMISSION/,
  'Android PDF viewer is not granted read permission');
assert.doesNotMatch(manifest, /WRITE_EXTERNAL_STORAGE|READ_EXTERNAL_STORAGE|READ_MEDIA_DOCUMENTS/,
  'Android PDF handling must not request broad storage access');

assert.match(manifest, /android\.intent\.action\.SEND/,
  'Android ACTION_SEND share target missing');
assert.match(manifest, /android\.intent\.action\.SEND_MULTIPLE/,
  'Android ACTION_SEND_MULTIPLE share target missing');
assert.match(manifest, /android:launchMode="singleTop"/,
  'Android share handoff must reuse the main Rantlist activity');
assert.match(android, /captureIncomingShareIntent\(getIntent\(\)\)/,
  'Android initial share intent is not captured');
assert.match(android, /onNewIntent\(Intent intent\)[\s\S]*?captureIncomingShareIntent\(intent\)/,
  'Android shares delivered to an existing Rantlist task are not captured');
assert.match(android, /createWebMessageChannel\(\)/,
  'Android origin-scoped share MessagePort missing');
assert.match(android, /rantlist-native-share-channel-v1/,
  'Android share channel identifier missing');
assert.doesNotMatch(android, /addJavascriptInterface/,
  'Android native share must not expose an all-frame JavaScript interface');

console.log(`PASS client ${read('PACKAGE_VERSION.txt').trim()} mobile reactions, iOS PDF return, Android PDF handoff and Android share target (r449+ source-compatible).`);
