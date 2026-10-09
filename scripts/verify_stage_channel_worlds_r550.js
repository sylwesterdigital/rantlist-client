#!/usr/bin/env node
'use strict';
const fs=require('fs'),assert=require('assert'),path=require('path');
const root=path.resolve(__dirname,'..');
const pkgVersion=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
const source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));
const web=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const releaseTarget=fs.readFileSync(path.join(root,'.watch-release-platform'),'utf8').trim();
assert(/^0\.1\.\d+$/.test(pkgVersion) && Number(pkgVersion.split('.')[2])>=308);
const versionParts=String(source.sourceVersion||'').split('.').map(Number);
assert(versionParts.length===3 && versionParts.every(Number.isFinite) && (versionParts[0]>9 || (versionParts[0]===9 && (versionParts[1]>6 || (versionParts[1]===6 && versionParts[2]>=522)))));
const revisionMatch=String(source.sourceRevision||'').match(/^rantlist-deploy-r(\d+)$/);
assert(revisionMatch && Number(revisionMatch[1])>=550);
assert.equal(releaseTarget,'all');
for(const marker of [
  "stageWorldAccess:{role:'viewer'",
  "case 'stage.world.library':",
  "stage.world.snapshot.restore_local",
  "stage.world.permission.set",
  "postToStage('channel-world-state'",
  "sendJson({type:'stage.world.library.request'}"
]) assert(web.includes(marker),`missing channel World bridge marker: ${marker}`);
// Stage permission labels live in the server-hosted Stage iframe; this public client verifies only the parent bridge.
assert(!web.includes('stage-world-library.js'),'public client must not bundle server persistence module');
console.log('PASS client r550 authoritative channel World bridge, roles and all-platform release target');
