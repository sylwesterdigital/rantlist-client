#!/usr/bin/env node
'use strict';
const fs=require('fs'),assert=require('assert'),path=require('path');
const root=path.resolve(__dirname,'..');
const pkgVersion=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
const source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));
const web=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const releaseTarget=fs.readFileSync(path.join(root,'.watch-release-platform'),'utf8').trim();
const pkgMatch=pkgVersion.match(/^0\.1\.(\d+)$/);
assert(pkgMatch && Number(pkgMatch[1])>=309,'client package must be 0.1.309 or later');
const v=String(source.sourceVersion||'').split('.').map(Number);
assert(v.length===3 && v.every(Number.isFinite) && (v[0]>9 || (v[0]===9 && (v[1]>6 || (v[1]===6 && v[2]>=523)))),'source version must be 9.6.523 or later');
const rev=String(source.sourceRevision||'').match(/^rantlist-deploy-r(\d+)$/);
assert(rev && Number(rev[1])>=551,'source revision must be r551 or later');
assert.equal(releaseTarget,'all');
for(const marker of [
  'stageJoinPending:false',
  'function requestStageWorldJoin(options={})',
  "case 'stage.world.permission.changed':",
  "case 'stage.world.player_limit.changed':",
  "postToStage('permission-notice'",
  "postToStage('player-limit-notice'",
  "if(data.event==='channel-world-player-limit')",
  "type:'stage.world.player_limit.set'"
]) assert(web.includes(marker),`missing r551 client bridge marker: ${marker}`);
assert(!web.includes("state.stageIsJoined=sendJson({type:'stage.world.join'"),'Stage join must not treat packet send as authoritative join acknowledgement');
console.log('PASS client r551 Stage permission notices, player capacity bridge and authoritative mobile hydration retry');
