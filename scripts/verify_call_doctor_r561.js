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
check('client r561 release metadata or later',()=>{const pm=pkg.match(/^0\.1\.(\d+)$/);assert(pm&&Number(pm[1])>=317);const sv=source.sourceVersion.split('.').map(Number);assert(sv[0]===9&&sv[1]===6&&sv[2]>=533);assert(Number(String(source.sourceRevision).match(/r(\d+)$/)?.[1])>=561);});
check('Doctor uses video-first workspace with vertical diagnostics',()=>{for(const token of ['call-doctor-workspace','call-doctor-visual-column','call-doctor-diagnostic-column'])assert(html.includes(token),token);});
check('Doctor video uses contain instead of cropping',()=>{for(const token of ['aspect-ratio: 16 / 9','object-fit: contain','object-position: center center'])assert(html.includes(token),token);});
check('Doctor can copy readable diagnosis and send sanitized txt to channel',()=>{for(const token of ['callDoctorCopyDiagnosisButton','callDoctorShareDiagnosisButton','buildCallDoctorDiagnosisText','sendCallDoctorDiagnosisToChannel','targetOverride: \'room\'','VERBOSE CONNECTION LOG (sanitized)'])assert(html.includes(token),token);});
check('browser snapshot stays syntactically valid',()=>{const start=html.indexOf("  <script>\n    'use strict';");assert(start>=0);const bodyStart=start+'  <script>\n'.length;const end=html.indexOf('</script>',bodyStart);new vm.Script(html.slice(bodyStart,end));});
console.log(`Client Call Doctor r561: ${n} checks passed.`);
