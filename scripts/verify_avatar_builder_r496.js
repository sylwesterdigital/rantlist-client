#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..');const html=fs.readFileSync(path.join(root,'web/index.html'),'utf8');const source=require(path.join(root,'web/client-source.json'));
let n=0;const check=(name,fn)=>{fn();n++;console.log('PASS '+name)};
check('client release metadata',()=>{assert(Number(fs.readFileSync(path.join(root,'VERSION.txt'),'utf8').trim().split('.')[2])>=468);assert(Number(fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim().split('.')[2])>=265);assert(Number(String(source.sourceRevision).replace(/\D/g,''))>=496)});
check('model cards keep image clear with current action visibility',()=>{assert(html.includes('.avatar-lab-models-panel.is-compact .avatar-lab-model-info{position:static!important'));assert(html.includes('style id="avatar-lab-r498"'));assert(html.includes('#avatarLabModelsPanel.avatar-lab-models-panel.is-compact .avatar-lab-model-actions>*{display:inline-flex!important'));assert(html.includes('avatarLabModelToolsPreviewImage'))});
check('optimization UI is measurable',()=>{for(const x of ['Target file','Target triangles','Texture max','WebP quality','Texture GPU','Max skin weights','avatarLabOptimizerComparison','id="avatarLabOptimizerPreset"'])assert(html.includes(x),x)});
check('pipeline is visible',()=>{for(const x of ['Blender Decimate','Texture resize + WebP','4-weight skin cleanup','Prune · dedup · weld','Meshopt compression','Animation key cleanup + resample'])assert(html.includes(x),x)});
check('optimized previews retain CSP-safe Draco loader',()=>{assert(!html.includes('meshopt_decoder.module.js'));assert(html.includes('DRACOLoader'));assert(html.includes("setDecoderConfig({type:'js'})"));assert(html.includes('setDRACOLoader'))});
console.log(`Avatar model UX + optimizer client r496: ${n} checks passed.`);
