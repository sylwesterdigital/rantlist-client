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
check('client r558 release metadata remains compatible',()=>{const pm=pkg.match(/^0\.1\.(\d+)$/);assert(pm&&Number(pm[1])>=314);const sm=String(source.sourceVersion).match(/^9\.6\.(\d+)$/);assert(sm&&Number(sm[1])>=530);const rm=String(source.sourceRevision).match(/^rantlist-deploy-r(\d+)$/);assert(rm&&Number(rm[1])>=558);});
check('Call Doctor UI and multi-user selection are packaged',()=>{for(const token of ['id="callDoctorButton"','id="callDoctorModal"','id="callDoctorUserList"','id="callDoctorAllInput"','id="callDoctorAudioButton"','id="callDoctorVideoButton"'])assert(html.includes(token),token);});
check('Call Doctor includes permission, stats and peer probe diagnostics',()=>{for(const token of ["callDoctorPermissionState('microphone')","callDoctorPermissionState('camera')",'peer.getStats()',"type: 'call.doctor.probe'","case 'call.doctor.reply':",'packetLossPercent','jitterMs','rttMs'])assert(html.includes(token),token);});
check('diagnostic calls reuse normal call stack',()=>{assert(html.includes("startCallInvite(media, targets, { diagnostic: true })"));assert(html.includes("type: 'call.invite', media: acquired.effectiveMedia, to: targets, allRoom, diagnostic:"));});
check('sanitized browser snapshot stays syntactically valid',()=>{const start=html.indexOf("  <script>\n    'use strict';");assert(start>=0);const bodyStart=start+'  <script>\n'.length;const end=html.indexOf('</script>',bodyStart);new vm.Script(html.slice(bodyStart,end));});
console.log(`Client Call Doctor r558: ${n} checks passed.`);
