#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const read=(...parts)=>fs.readFileSync(path.join(root,...parts),'utf8');
const html=read('web','index.html');
const source=JSON.parse(read('web','client-source.json'));
const pkg=read('PACKAGE_VERSION.txt').trim();
let n=0;const check=(name,fn)=>{fn();n++;console.log('PASS '+name);};
check('client r559 release metadata or later',()=>{const pm=pkg.match(/^0\.1\.(\d+)$/);assert(pm&&Number(pm[1])>=315);const sv=source.sourceVersion.split('.').map(Number);assert(sv[0]===9&&sv[1]===6&&sv[2]>=531);const rm=String(source.sourceRevision||'').match(/^rantlist-deploy-r(\d+)$/);assert(rm&&Number(rm[1])>=559);});
check('Doctor picker follows current channel roster',()=>{for(const token of ['for (const user of state.users || [])','for (const user of state.globalUsers || [])','merged.set(user.id'])assert(html.includes(token),token);});
check('Doctor performs relay-only TURN self-test',()=>{for(const token of ['async function runCallDoctorIceProbe','iceTransportPolicy: \'relay\'','rantlist-call-doctor','relayCandidates','TURN self-test'])assert(html.includes(token),token);});
check('Doctor explains specific connection failures',()=>{for(const token of ['TURN DNS/host lookup failed','ICE error 701','TURN authentication failed','relay-only, so media cannot connect','Rantlist signaling is reachable','Current diagnosis'])assert(html.includes(token),token);});
check('browser snapshot stays syntactically valid',()=>{const start=html.indexOf("  <script>\n    'use strict';");assert(start>=0);const bodyStart=start+'  <script>\n'.length;const end=html.indexOf('</script>',bodyStart);new vm.Script(html.slice(bodyStart,end));});
console.log(`Client Call Doctor r559: ${n} checks passed.`);
