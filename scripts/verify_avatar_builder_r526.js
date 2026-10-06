#!/usr/bin/env node
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert');
const root=path.resolve(__dirname,'..');
const html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');
const pkg=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
const ver=fs.readFileSync(path.join(root,'VERSION.txt'),'utf8').trim();
const source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));
let n=0;const check=(name,fn)=>{fn();n++;console.log(`PASS ${name}`);};
check('client r526 release metadata remains compatible',()=>{const pv=pkg.split('.').map(Number),vv=ver.split('.').map(Number),sv=String(source.sourceVersion||'').split('.').map(Number),rev=Number(String(source.sourceRevision||'').match(/r(\d+)$/)?.[1]||0);assert.equal(pv[0],0);assert.equal(pv[1],1);assert.ok(pv[2]>=275);assert.equal(vv[0],9);assert.equal(vv[1],6);assert.ok(vv[2]>=498);assert.equal(sv[0],9);assert.equal(sv[1],6);assert.ok(sv[2]>=498);assert.ok(rev>=526)});
check('client four-view picker assigns My Images to selected slot',()=>{assert(!html.includes("if(state.avatarLabMultiviewEnabled&&!state.avatarLabMultiview.front)"));assert(html.includes("state.avatarLabMultiview[slot]=String(item.url||'')"));assert(html.includes('const multiviewSelectedUrl=multiviewEnabled?String(state.avatarLabMultiview?.[multiviewSelectedSlot]'));});
check('client compact Source Reference and restored collapsed My Models',()=>{assert(!html.includes('id="profileAvatarSuitePreviewMeta"'));assert(html.includes('.avatar-lab-source-card>header,.avatar-lab-generated-card>header{padding:7px 8px 18px!important;'));assert(html.includes('#avatarLabModelsPanel.avatar-lab-models-panel.is-collapsed #avatarLabModelsMeta{display:none!important;}'));});
check('client prompt uses visible rotating SVG chevron',()=>{assert(html.includes('class="avatar-lab-prompt-chevron"'));assert(html.includes('M12 7C12.2652 7 12.5196 7.10536'));assert(html.includes('.avatar-lab-prompt-details[open] .avatar-lab-prompt-chevron{transform:rotate(0deg)'));});
console.log(`Client Avatar Lab r526: ${n} regression groups passed.`);
