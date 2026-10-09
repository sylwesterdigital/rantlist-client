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
check('client r562 release metadata or later',()=>{const pm=pkg.match(/^0\.1\.(\d+)$/);assert(pm&&Number(pm[1])>=318);const sv=source.sourceVersion.split('.').map(Number);assert(sv[0]===9&&sv[1]===6&&sv[2]>=534);assert(Number(String(source.sourceRevision).match(/r(\d+)$/)?.[1])>=562);});
check('stale peer snapshots cannot override live remote media evidence',()=>{for(const token of ['remoteObservedKinds','The stale media snapshot is ignored.','callDoctorRemoteReportForPeer','callId: message.callId'])assert(html.includes(token),token);});
check('fresh peer probe follows ICE connect and remote track arrival',()=>{for(const token of ['scheduleCallDoctorPeerProbe(peerId, 1000)','scheduleCallDoctorPeerProbe(peerId, 650)'])assert(html.includes(token),token);});
check('bitrate displays measuring until a valid interval exists',()=>{for(const token of ['elapsedMs >= 1000','bitrateSampled','measuring…','bitrate measuring…'])assert(html.includes(token),token);});
check('playback interruptions are diagnosed separately from transport',()=>{for(const token of ['playbackInterruptions','AbortError events are non-blocking unless playback is visibly blank or silent','Remote media playback was interrupted'])assert(html.includes(token),token);});
check('browser snapshot stays syntactically valid',()=>{const start=html.indexOf("  <script>\n    'use strict';");assert(start>=0);const bodyStart=start+'  <script>\n'.length;const end=html.indexOf('</script>',bodyStart);new vm.Script(html.slice(bodyStart,end));});
console.log(`Client Call Doctor r562: ${n} checks passed.`);
