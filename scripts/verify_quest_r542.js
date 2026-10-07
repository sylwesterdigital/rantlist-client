#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');let n=0;function check(x,f){f();n++;console.log('PASS '+x)}
const pkg=read('PACKAGE_VERSION.txt').trim(),src=JSON.parse(read('web/client-source.json')),build=read('scripts/build_quest_release.sh'),inj=read('scripts/inject_quest_xr_bridge.js');
check('client r542 metadata is current',()=>{assert.equal(pkg,'0.1.291');assert.equal(src.sourceVersion,'9.6.514');assert.equal(src.sourceRevision,'rantlist-deploy-r542')});
check('Quest build remains Bubblewrap plus XR bridge injection',()=>{assert(build.includes('@meta-quest/bubblewrap-cli'));assert(build.includes('update --skipVersionUpgrade'));assert(build.includes('inject_quest_xr_bridge.js'));assert(build.indexOf('update --skipVersionUpgrade')<build.indexOf('inject_quest_xr_bridge.js'))});
check('Quest bridge runtime remains unchanged',()=>{assert(inj.includes('WebXRCustomTabActivity'));assert(inj.includes('rantlistxr'));assert(inj.includes('https://rantlist.me/stage/?rantlistImmersive=1'))});
console.log(`Client r542 Quest bridge compatibility: ${n} regression groups passed.`);
