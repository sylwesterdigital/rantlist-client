#!/usr/bin/env node
'use strict';
const fs=require('fs'),assert=require('assert'),path=require('path');
const root=path.resolve(__dirname,'..');
const version=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
const web=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
assert(/^0\.1\.\d+$/.test(version) && Number(version.split('.')[2]) >= 307);
assert(Number(web.match(/<meta name="chat-ui-version" content="9\.6\.(\d+)">/)?.[1]||0)>=519);
assert(web.includes("const STAGE_BOOKMARK_CHAT_CAPTION_PREFIX = '[[RANTLIST_STAGE_BOOKMARK_V1:'"));
assert(web.includes("button.textContent = 'Teleport'"));
assert(web.includes("postToStage('bookmark-teleport', { bookmark: clean.bookmark })"));
assert(web.includes("if(data.event==='bookmark-share')"));
assert(/targetOverride\s*:\s*'room'/.test(web));
assert(web.includes('viewQuaternion: sanitizeStageBookmarkQuaternion(rawBookmark.viewQuaternion)'));
console.log('PASS client r547 Stage bookmark chat transport and teleport action');
