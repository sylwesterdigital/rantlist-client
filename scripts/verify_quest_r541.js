#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');let n=0;function check(x,f){f();n++;console.log('PASS '+x)}
const pkg=read('PACKAGE_VERSION.txt').trim(),src=JSON.parse(read('web/client-source.json')),build=read('scripts/build_quest_release.sh'),inj=read('scripts/inject_quest_xr_bridge.js');
check('client r541 metadata remains compatible',()=>{const pv=pkg.split('.').map(Number),sv=src.sourceVersion.split('.').map(Number),rr=Number((src.sourceRevision.match(/r(\d+)$/)||[])[1]||0);assert(pv[0]>0||pv[1]>1||pv[2]>=290);assert(sv[0]>9||sv[0]===9&&sv[1]>6||sv[0]===9&&sv[1]===6&&sv[2]>=513);assert(rr>=541)});
check('Quest build remains Bubblewrap plus XR bridge injection',()=>{assert(build.includes('@meta-quest/bubblewrap-cli'));assert(build.includes('update --skipVersionUpgrade'));assert(build.includes('inject_quest_xr_bridge.js'));assert(build.indexOf('update --skipVersionUpgrade')<build.indexOf('inject_quest_xr_bridge.js'))});
check('Quest bridge runtime remains unchanged',()=>{assert(inj.includes('WebXRCustomTabActivity'));assert(inj.includes('rantlistxr'));assert(inj.includes('https://rantlist.me/stage/?rantlistImmersive=1'))});
console.log(`Client r541 Quest bridge compatibility: ${n} regression groups passed.`);
