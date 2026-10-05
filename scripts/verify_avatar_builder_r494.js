#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');let n=0;const c=(x,f)=>{f();n++;console.log('PASS '+x)};
const pkg=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
const version=fs.readFileSync(path.join(root,'VERSION.txt'),'utf8').trim();
const source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));
const html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
c('client remains r494-compatible or later',()=>{const pv=pkg.split('.').map(Number),sv=version.split('.').map(Number);assert.equal(pv[0],0);assert.equal(pv[1],1);assert.ok(pv[2]>=263);assert.equal(sv[0],9);assert.equal(sv[1],6);assert.ok(sv[2]>=466);assert.equal(source.sourceVersion,version);assert.match(source.sourceRevision,/^rantlist-deploy-r\d+$/)});
c('clean Avatar Lab UI remains synchronized',()=>{assert.doesNotMatch(html,/class="avatar-lab-flow"/);assert.doesNotMatch(html,/id="profileAvatar3dRequireFingersInput"[^>]*type="checkbox"/);assert.match(html,/id="avatarLabModelsAddButton"[^>]*>Import GLB\/FBX<\/button>/)});
c('current hand validation remains explicit and release-forward',()=>{assert.ok(/requireFingers:true/.test(html)||/requireFingers:Boolean\(elements\.profileAvatar3dRequireFingersInput\?\.checked\)/.test(html));assert.match(html,/Strict hand validation/);assert.doesNotMatch(html,/complete 30-bone finger chain/)});
console.log(`PASS client Avatar Lab verifier recovery r494 (${n} groups)`);
