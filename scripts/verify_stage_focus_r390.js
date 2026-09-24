#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const {versionAtLeast,revisionAtLeast}=require('./assert_compatible_release');
const root=path.resolve(__dirname,'..');const web=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const meta=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));
const clientVersion=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
assert(versionAtLeast(clientVersion,'0.1.197'));
assert(versionAtLeast(meta.sourceVersion,'9.6.362')&&revisionAtLeast(meta.sourceRevision,390));
assert.equal(meta.sourceVersion,fs.readFileSync(path.join(root,'VERSION.txt'),'utf8').trim());
assert(web.includes('<meta name="rantlist-public-client-snapshot" content="sanitized">'));
for(const marker of [
  'function syncStageChatOverlay()','function toggleStageChatOverlay()','function setStageFocusMode(active)',
  'state.stageOverlayVisible=!state.stageOverlayVisible;','elements.composerShell.insertBefore(eye,elements.sendButton)',
  'elements.messageViewport.insertBefore(eye,elements.stageEditStatus)',
  'body.stage-focus-mode #workspace > :not(#chatPanel) {display:none!important;}',
  'body.stage-focus-mode #chatPanel #messageForm {',
  "if(!open && state.stageFocusMode)setStageFocusMode(false);",
  "if(data.event==='focus-mode-toggle')",
  "postToStage('focus-mode-state',{active:state.stageFocusMode})",
])assert(web.includes(marker),`Missing synchronized focus/eye browser feature: ${marker}`);
assert(fs.existsSync(path.join(root,'web/assets/icons/full.svg')),'sanitized supplied icon absent from browser assets');
console.log('Full native client r390 sanitized browser-core eye/focus regression passed.');
