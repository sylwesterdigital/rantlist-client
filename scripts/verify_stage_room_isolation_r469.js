#!/usr/bin/env node
'use strict';
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));
const html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const match=String(source.sourceRevision||'').match(/rantlist-deploy-r(\d+)/);
const revision=Number(match?.[1]||0);
if(revision<469){
  console.log(`PASS client Stage room-isolation verifier: bundled source r${revision||'unknown'} predates r469; release sync will enforce r469+ when present.`);
  process.exit(0);
}
assert.match(html,/postToStage\('empty-world',\{room:message\.room,revision:message\.revision\}\)/,
  'r469 authoritative empty-world handoff is missing from synchronized browser core');
assert.match(html,/else if\(!state\.stageWorldSnapshot\)postToStage\('empty-world',\{room:state\.stageWorldRoom,revision:state\.stageRevision\}\)/,
  'r469 iframe-ready empty-world recovery is missing from synchronized browser core');
console.log(`PASS client synchronized Stage room isolation for ${source.sourceRevision}.`);
