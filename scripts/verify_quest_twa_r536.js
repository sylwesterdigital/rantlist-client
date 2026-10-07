#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');
const pkg=read('PACKAGE_VERSION.txt').trim().split('.').map(Number),source=JSON.parse(read('web/client-source.json'));let n=0;
function check(name,fn){fn();n++;console.log('PASS '+name);}
check('client r536 metadata is current or later',()=>{const s=source.sourceVersion.split('.').map(Number),r=Number(String(source.sourceRevision).match(/r(\d+)$/)?.[1]);assert.ok(pkg[2]>=280);assert.ok(s[2]>=508);assert.ok(r>=536);});
check('Quest TWA contract is release-forward',()=>{if(pkg[2]>=283){const t=JSON.parse(read('mobile/quest/twa-manifest.template.json'));assert.equal(t.isMetaQuest,true);assert.equal(t.horizonOSAppMode,'2D');assert(read('scripts/build_quest_release.sh').includes('@meta-quest/bubblewrap-cli'));}else{assert(fs.existsSync(path.join(root,'mobile/quest/app/build.gradle')));}});
console.log(`Client Quest TWA r536 compatibility: ${n} regression groups passed.`);
