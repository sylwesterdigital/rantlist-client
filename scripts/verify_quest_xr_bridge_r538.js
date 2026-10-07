#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');let n=0;function check(x,f){f();n++;console.log('PASS '+x)}
const pkg=read('PACKAGE_VERSION.txt').trim(),src=JSON.parse(read('web/client-source.json')),build=read('scripts/build_quest_release.sh'),inj=read('scripts/inject_quest_xr_bridge.js'),web=read('web/index.html');
check('client r538-or-later metadata remains compatible',()=>{const pv=pkg.split('.').map(Number),sv=src.sourceVersion.split('.').map(Number),rr=Number(String(src.sourceRevision).match(/r(\d+)$/)?.[1]||0);assert(pv[0]===0&&pv[1]===1&&pv[2]>=287);assert(sv[0]===9&&sv[1]===6&&sv[2]>=510);assert(rr>=538)});
check('Bubblewrap build injects bridge after generation',()=>{assert(build.includes('inject_quest_xr_bridge.js'));assert(build.indexOf('update --skipVersionUpgrade')<build.indexOf('inject_quest_xr_bridge.js'));assert(build.indexOf('inject_quest_xr_bridge.js')<build.indexOf('"${BUBBLEWRAP[@]}" build'))});
check('bridge accepts only Rantlist Stage and launches Meta immersive activity',()=>{assert(inj.includes('rantlistxr'));assert(inj.includes('WebXRCustomTabActivity'));assert(inj.includes('WebVRActivity'));assert(inj.includes('rantlist.me'));assert(inj.includes('path.startsWith("/stage/")'))});
check('web client routes Quest PWA Enter VR to same-package bridge',()=>{assert(web.includes('fun.workwork.rantlist/.XRBridgeActivity'));assert(web.includes('rantlistImmersive'));assert(web.includes('scheme=rantlistxr'))});
console.log(`Client Quest immersive bridge r538: ${n} regression groups passed.`);
