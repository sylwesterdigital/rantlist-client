#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');const root=path.resolve(__dirname,'..');
const pkg=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();const source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));const html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');let count=0;const check=(label,fn)=>{fn();count++;console.log('PASS '+label)};
check('client is 0.1.256 / source r487 or later',()=>{assert.ok(Number(pkg.split('.').at(-1))>=256);const p=String(source.sourceVersion||'').split('.').map(Number);assert.equal(p[0],9);assert.equal(p[1],6);assert.ok(p[2]>=459);assert.ok(Number(String(source.sourceRevision||'').match(/r(\d+)$/)?.[1])>=487);});
check('client renders real builder stage detail and elapsed time',()=>{for(const token of ['buildStage','buildDetail','buildLog','buildStartedAt','elapsed'])assert.ok(html.includes(token),token);});
check('client preserves known incomplete-hand validation',()=>{assert.match(html,/avatarBuilderRigFingerCounts/);assert.match(html,/knownFingers<30/);assert.ok(/Finger rig requirement not met/.test(html)||/Strict hand validation not met/.test(html),'current incomplete-hand validation copy missing');});
console.log(`PASS client Avatar Builder observability r487 (${count} groups)`);
