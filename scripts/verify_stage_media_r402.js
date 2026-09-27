#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'web/index.html'),'utf8'),meta=require('../web/client-source.json');
// This r402 feature regression runs with every later paired client release.
const currentServerVersion=fs.readFileSync(path.join(root,'VERSION.txt'),'utf8').trim();
const currentClientVersion=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
assert.equal(meta.sourceVersion,currentServerVersion);
assert.match(meta.sourceRevision,/^rantlist-deploy-r\d+$/);
assert.match(currentClientVersion,/^0\.1\.\d+$/);
assert.equal(html.match(/<meta name="chat-ui-version" content="([^"]+)/)?.[1],currentServerVersion);
assert.match(html,/data-stage-media-r402|stage-frame-media-picker/);
assert.match(html,/if\(data.event==='media-picker-open'\)/);
assert.match(html,/shouldHideMessage\(message\)/);
assert.match(html,/!sameRoom\(message.room,state.currentRoom\)/);
assert.match(html,/message.target==='user'/);
assert.match(html,/function stageRoomMediaChoices\(\)/);
assert.match(html,/postToStage\('frame-media-choice'/);
assert.match(html,/closeStageFrameMediaPicker\(null\);\s*state.currentRoom = message.room/);
const match=[...html.matchAll(/<script([^>]*)>([\s\S]*?)<\/script>/gi)].sort((a,b)=>b[2].length-a[2].length)[0];
const os=require('node:os'),f=path.join(os.tmpdir(),'r402-client-syntax-'+process.pid+'.js');try{fs.writeFileSync(f,match[2]);const out=cp.spawnSync(process.execPath,['--check',f],{encoding:'utf8'});assert.equal(out.status,0,out.stderr);}finally{try{fs.unlinkSync(f)}catch{}}
console.log('PASS client r402 authenticated channel media picker + version and JS syntax');
