#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const html=read('web/index.html'),source=JSON.parse(read('web/client-source.json')),pkg=read('PACKAGE_VERSION.txt').trim(),ver=read('VERSION.txt').trim();
let n=0;const check=(name,fn)=>{fn();n++;console.log('PASS '+name)};
check('client r524 release metadata remains compatible',()=>{const pv=pkg.split('.').map(Number),vv=ver.split('.').map(Number),sv=String(source.sourceVersion||'').split('.').map(Number),rev=Number(String(source.sourceRevision||'').match(/r(\d+)$/)?.[1]||0);assert.equal(pv[0],0);assert.equal(pv[1],1);assert.ok(pv[2]>=273);assert.equal(vv[0],9);assert.equal(vv[1],6);assert.ok(vv[2]>=496);assert.equal(sv[0],9);assert.equal(sv[1],6);assert.ok(sv[2]>=496);assert.ok(rev>=524)});
check('2D settings stay visible and expose current xAI controls',()=>{assert(html.includes('avatar-lab-reference-settings'));assert(html.includes('profileAvatarGrokQuality'));assert(html.includes('grok-imagine-image-2.0'));assert(html.includes('position:fixed!important'))});
check('four-view reference workflow is present',()=>{for(const token of ['data-avatar-view="front"','data-avatar-view="left"','data-avatar-view="back"','data-avatar-view="right"','avatarLabMultiviewDataUrls'])assert(html.includes(token),token)});
check('optimization versions and selected optimized stage are present',()=>{assert(html.includes('optimizationVersions'));assert(html.includes("state.avatar3dSelectedVariant='optimized'"));assert(html.includes("variant.startsWith('optimized:')"))});
check('local built-in rig does not hard-require fingers',()=>{assert(html.includes("requireFingers:engine==='addon'"))});
console.log(`Client Avatar Lab r524: ${n} regression groups passed.`);
