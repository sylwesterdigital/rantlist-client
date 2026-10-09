#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');
const pkg=read('PACKAGE_VERSION.txt').trim(),src=JSON.parse(read('web/client-source.json')),html=read('web/index.html'),home=read('homepage/index.html');
const pm=pkg.match(/^0\.1\.(\d+)$/);assert(pm&&Number(pm[1])>=310,'client package must be 0.1.310 or later');
const sv=String(src.sourceVersion||'').split('.').map(Number);assert(sv.length===3&&sv.every(Number.isFinite)&&sv[0]===9&&sv[1]===6&&sv[2]>=526,'source version must be 9.6.526 or later');
assert(/^rantlist-deploy-r\d+$/.test(src.sourceRevision)&&Number(src.sourceRevision.match(/r(\d+)$/)[1])>=554,'source revision must be r554 or later');
assert(html.includes("['engineering.sync','engineering.remove'].includes(message.edit?.op)"),'parent bridge must route compact vehicle removal');
assert(html.includes("}else if(edit.op==='engineering.remove'){"),'parent cache must remove authoritative vehicle graph');
assert(html.includes('if(chassisIndex<0){')&&html.includes('if(!edit.chassis?.record)return null;'),'parent cache must hydrate a newly seeded saved-vehicle chassis');
assert(home.includes(`data-development-release="${src.sourceRevision}"`)&&home.includes(`Rantlist ${src.sourceVersion}`),'homepage development log must include synchronized r554 release');
console.log('PASS client 0.1.310+ carries r554 authoritative vehicle graph bridge and homepage release metadata.');
