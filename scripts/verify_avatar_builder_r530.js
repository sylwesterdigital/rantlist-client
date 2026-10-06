#!/usr/bin/env node
'use strict';
const assert=require('node:assert'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');
const html=read('web/index.html'),source=JSON.parse(read('web/client-source.json')),pkg=read('PACKAGE_VERSION.txt').trim(),ver=read('VERSION.txt').trim();
let n=0;const check=(name,fn)=>{fn();n++;console.log(`PASS ${name}`);};
check('client r530 release metadata',()=>{const pv=pkg.split('.').map(Number),vv=ver.split('.').map(Number),sv=String(source.sourceVersion||'').split('.').map(Number),rev=Number(String(source.sourceRevision||'').match(/r(\d+)$/)?.[1]||0);assert.equal(pv[0],0);assert.equal(pv[1],1);assert.ok(pv[2]>=277);assert.equal(vv[0],9);assert.equal(vv[1],6);assert.ok(vv[2]>=502);assert.equal(sv[0],9);assert.equal(sv[1],6);assert.ok(sv[2]>=502);assert.ok(rev>=530);});
check('Avatar Lab Stage preview prefers Blender-safe artifact',()=>{assert(html.includes("variant==='stage'?(item?.builtPreviewUrl||(!/meshopt/i.test(String(item?.buildCompression||''))?item?.builtUrl:null))"));assert(html.includes("editable.textContent='Blender'"));assert(html.includes("editable.href=item.builtPreviewUrl"));assert(!html.includes('setMeshoptDecoder(stage.MeshoptDecoder)'));});
check('optional local rig add-on is hidden when unavailable',()=>{assert(html.includes('addonOption.hidden=!localRig.addonAvailable'));assert(!html.includes("'Server Blender add-on · not configured'"));});
console.log(`Client Avatar Lab r530: ${n} regression groups passed.`);
