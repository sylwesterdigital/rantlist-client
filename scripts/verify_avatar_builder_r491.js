#!/usr/bin/env node
'use strict';const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');const root=path.resolve(__dirname,'..');const pkg=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim(),source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8')),html=fs.readFileSync(path.join(root,'web/index.html'),'utf8'),ios=fs.readFileSync(path.join(root,'mobile/ios/Rantlist/RantlistApp.swift'),'utf8'),mac=fs.readFileSync(path.join(root,'macos/RantlistApp.swift'),'utf8'),android=fs.readFileSync(path.join(root,'mobile/android/app/src/main/java/fun/workwork/rantlist/MainActivity.java'),'utf8');let n=0;const check=(l,f)=>{f();n++;console.log('PASS '+l)};
check('client remains r491-compatible or later',()=>{assert.ok(Number(source.sourceRevision.match(/r(\d+)/)?.[1]||0)>=491);assert.ok(/^0\.1\.\d+$/.test(pkg))});
check('Meshy remains a secure optional provider',()=>{assert.match(html,/Meshy API key/);assert.match(html,/meshyEphemeralApiKey/);assert.match(html,/\['openai','tripo','meshy','xai'\]/);});
check('native secure stores accept Meshy provider',()=>{assert.match(ios,/"meshy"/);assert.match(mac,/"meshy"/);assert.match(android,/"meshy"\.equals\(provider\)/)});
check('automatic final build retains finger validation',()=>assert.match(html,/requireFingers:true/));
check('build status polling is self-healing',()=>assert.match(html,/scheduleAvatar3dBuildPoll\(taskId,0\),2500/));
console.log(`PASS client automatic humanoid rigging r491 compatibility (${n} groups)`);
