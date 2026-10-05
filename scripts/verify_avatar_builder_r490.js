#!/usr/bin/env node
'use strict';const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'web/index.html'),'utf8'),src=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));let n=0;const c=(x,f)=>{f();n++;console.log('PASS '+x)};
c('source remains r490-compatible or later',()=>assert.ok(Number(src.sourceRevision.match(/r(\d+)/)?.[1]||0)>=490));
c('no stray 2D label',()=>{assert.match(html,/id="profileAvatarGrokRunButton"[^>]*aria-label="Generate reference image"/);assert.doesNotMatch(html,/profileAvatarGrokRunButton[^\n]{0,240}<span>2D<\/span>/)});
c('unified import replaces dual technical choices',()=>{assert.match(html,/Import GLB\/FBX/);assert.doesNotMatch(html,/Unrigged GLB\/FBX → rig only|Rigged GLB\/FBX → add actions/)});
c('animation picker remains scroll-stable',()=>{assert.match(html,/const previousScroll=host\.scrollTop/);assert.match(html,/host\.scrollTop=previousScroll/)});
console.log(`PASS client Avatar Builder r490 compatibility (${n} groups)`);
