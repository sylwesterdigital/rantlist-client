#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),root=path.resolve(__dirname,'..');
const pkg=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim(),source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8')),html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');let n=0;const check=(l,f)=>{f();n++;console.log('PASS '+l)};
check('client is 0.1.257 / r488 or later',()=>{assert.ok(Number(pkg.split('.').at(-1))>=257);assert.ok(Number(String(source.sourceRevision).match(/r(\d+)$/)[1])>=488);});
check('source-to-reference direct workflow is present',()=>{for(const t of ['avatarLabSourceUseReferenceButton','avatarLabSourceAsReference','direct A-pose reference'])assert.ok(html.includes(t),t);});
check('existing model import modes are present',()=>{for(const t of ['avatarLabModelsAddButton','avatarLabImportUnriggedButton','avatarLabImportRiggedButton','avatarLabModelImportInput','uploadAvatar3dImport'])assert.ok(html.includes(t),t);});
check('detailed builder log replay is present',()=>{assert.match(html,/avatarBuilderSeenServerLogs/);assert.match(html,/for\(const serverLog of serverLogs\)/);});
console.log(`PASS client Avatar Lab import/continuation r488 (${n} groups)`);
