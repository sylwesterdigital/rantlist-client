#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const app=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const metadata=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));
assert(app.includes("postToStage('speech',{clientId:message.from.id"),'Stage chat projection missing from synced browser client');
assert(app.includes("postToStage('typing',{clientId:message.from.id"),'Stage typing projection missing from synced browser client');
assert(app.includes("message.target==='room' && sameRoom(message.room,state.currentRoom)"),'Stage typing is not scoped to room-only messages');
assert(app.includes('<meta name="rantlist-public-client-snapshot" content="sanitized">'));
assert.equal(metadata.sourceVersion,fs.readFileSync(path.join(root,'VERSION.txt'),'utf8').trim());assert.match(metadata.sourceRevision,/^rantlist-deploy-r\d+$/);
console.log('PASS r395 synchronized and sanitized native/browser Stage speech and typing client');
