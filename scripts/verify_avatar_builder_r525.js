#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const html=read('web/index.html'),source=JSON.parse(read('web/client-source.json')),pkg=read('PACKAGE_VERSION.txt').trim(),ver=read('VERSION.txt').trim();
let n=0;const check=(name,fn)=>{fn();n++;console.log('PASS '+name)};
check('client r525 release metadata remains compatible',()=>{const pv=pkg.split('.').map(Number),vv=ver.split('.').map(Number),sv=String(source.sourceVersion||'').split('.').map(Number),rev=Number(String(source.sourceRevision||'').match(/r(\d+)$/)?.[1]||0);assert.equal(pv[0],0);assert.equal(pv[1],1);assert.ok(pv[2]>=274);assert.equal(vv[0],9);assert.equal(vv[1],6);assert.ok(vv[2]>=497);assert.equal(sv[0],9);assert.equal(sv[1],6);assert.ok(sv[2]>=497);assert.ok(rev>=525)});
check('Tripo start request has stable client id and server progress channel',()=>{for(const token of ['avatar3dStartRequestId','avatar3d.start.progress','avatar3d.tripo.start.status','scheduleAvatar3dStartHeartbeat','handleAvatar3dStartProgress'])assert(html.includes(token),token)});
check('Tripo startup shows payload credential upload retry and task phases',()=>{for(const token of ['Request reached server','Reference payload accepted','Checking Tripo key','Uploading reference','Reference upload retry','Creating Tripo task','Tripo task accepted'])assert(html.includes(token),token)});
check('WebSocket reconnect checks same Tripo start instead of creating another render',()=>{assert(html.includes('3D start reconnect check'));assert(html.includes("sendJson({type:'avatar3d.tripo.start.status',startRequestId:state.avatar3dStartRequestId})"))});
check('r524 Avatar Lab features remain present',()=>{for(const token of ['profileAvatarGrokQuality','grok-imagine-image-2.0','avatarLabMultiviewDataUrls','optimizationVersions',"requireFingers:engine==='addon'"])assert(html.includes(token),token)});
console.log(`Client Avatar Lab r525: ${n} regression groups passed.`);
