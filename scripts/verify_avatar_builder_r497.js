#!/usr/bin/env node
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..');const html=fs.readFileSync(path.join(root,'web','index.html'),'utf8');const source=require(path.join(root,'web','client-source.json'));
function check(n,f){f();console.log('PASS '+n)}
check('client source metadata r497 or later',()=>{const v=String(source.sourceVersion||'').split('.').map(Number);assert.equal(v[0],9);assert.equal(v[1],6);assert.ok(v[2]>=469);assert.ok(Number(String(source.sourceRevision||'').match(/r(\d+)$/)?.[1])>=497)});
check('compact model shelf keeps action row visible',()=>{assert(html.includes('style id="avatar-lab-r498"'));assert(html.includes('.avatar-lab-model-actions>*{display:inline-flex!important'));});
check('dense optimizer and collapsible prompt/actions',()=>{assert(html.includes('avatar-lab-prompt-details'));assert(html.includes('height:72px!important'));assert(html.includes('<details class="avatar-lab-model-animation-section">'));});
check('Meshy is optional in UI',()=>{assert(html.includes('Meshy API key (optional alternative)'));assert(html.includes('Auto-rig after generation · Tripo'));});
console.log('Avatar Lab client UX r497: 4 checks passed.');
