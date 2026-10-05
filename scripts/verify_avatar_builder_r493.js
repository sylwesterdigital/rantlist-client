#!/usr/bin/env node
'use strict';const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');const root=path.resolve(__dirname,'..'),pkg=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim(),source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8')),html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');let n=0;const c=(x,f)=>{f();n++;console.log('PASS '+x)};
c('client is r493-compatible or later',()=>{const pv=pkg.split('.').map(Number),sv=source.sourceVersion.split('.').map(Number);assert.equal(pv[0],0);assert.equal(pv[1],1);assert.ok(pv[2]>=262);assert.equal(sv[0],9);assert.equal(sv[1],6);assert.ok(sv[2]>=465);assert.match(source.sourceRevision,/^rantlist-deploy-r\d+$/)});
c('flow pills are removed',()=>assert.doesNotMatch(html,/class="avatar-lab-flow"/));
c('Reference xAI key shortcut is wired',()=>{assert.match(html,/id="profileAvatarGrokKeysButton"/);assert.match(html,/profileAvatarGrokKeysButton\?\.addEventListener[\s\S]{0,220}xaiApiKeyInput/)});
c('single model import and model tools are present',()=>{assert.match(html,/Import GLB\/FBX/);for(const id of ['avatarLabModelToolsPanel','avatarLabModelMetrics','avatarLabOptimizeButton'])assert.ok(html.includes(`id="${id}"`),id)});
c('client speaks inspect and optimize protocol',()=>{assert.match(html,/avatar3d\.inspect\.start/);assert.match(html,/avatar3d\.optimize\.start/);assert.match(html,/avatar3d\.optimize\.status/)});
console.log(`PASS client Avatar Lab model tools r493 (${n} groups)`);
