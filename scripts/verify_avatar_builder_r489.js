#!/usr/bin/env node
'use strict';const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'web/index.html'),'utf8'),src=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));let n=0;const c=(x,f)=>{f();n++;console.log('PASS '+x)};
c('source remains r489-compatible or later',()=>assert.ok(Number(src.sourceRevision.match(/r(\d+)/)?.[1]||0)>=489));
c('Source reference action stays compact',()=>{assert.match(html,/id="avatarLabSourceUseReferenceButton"[^>]*>→<\/button>/);assert.doesNotMatch(html,/→ Reference/)});
c('animation controls remain compact',()=>{assert.match(html,/width:12px!important/);assert.match(html,/height:12px!important/)});
c('model import remains visible',()=>assert.match(html,/id="avatarLabModelsAddButton"[^>]*>Import GLB\/FBX<\/button>/));
console.log(`PASS client Avatar Builder r489 compatibility (${n} groups)`);
