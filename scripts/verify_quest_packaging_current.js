#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert'),cp=require('child_process');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');
const pkg=read('PACKAGE_VERSION.txt').trim();
const parts=pkg.split('.').map(Number);
const template=JSON.parse(read('mobile/quest/twa-manifest.template.json'));
const build=read('scripts/build_quest_release.sh');
const writer=read('scripts/write_quest_twa_manifest.js');
const phone=read('mobile/android/app/src/main/AndroidManifest.xml');
const web=read('web/index.html');
let n=0;function check(name,fn){fn();n++;console.log('PASS '+name)}
check('Quest package is 0.1.305 or later',()=>assert(parts.length===3&&parts.every(Number.isInteger)&&(parts[0]>0||parts[1]>1||(parts[1]===1&&parts[2]>=304))));
check('Quest uses official Meta Bubblewrap 1.24.1',()=>{assert(build.includes('@meta-quest/bubblewrap-cli@${BUBBLEWRAP_VERSION}'));assert(build.includes('BUBBLEWRAP_VERSION="${RANTLIST_QUEST_BUBBLEWRAP_VERSION:-1.24.1}"'));assert(build.includes('update --skipVersionUpgrade'));assert(build.includes('"${BUBBLEWRAP[@]}" build'));assert(!build.includes('inject_quest_xr_bridge.js'));});
check('Quest package is an immersive-capable Bubblewrap PWA',()=>{assert.equal(template.packageId,'fun.workwork.rantlist');assert.equal(template.isMetaQuest,true);assert.equal(template.horizonOSAppMode,'immersive');assert.equal(template.display,'standalone');assert.equal(template.startUrl,'/?rantlistPwa=1');assert.equal(template.webManifestUrl,'https://rantlist.me/manifest.webmanifest');assert(writer.includes("manifest.horizonOSAppMode='immersive'"));assert(!fs.existsSync(path.join(root,'mobile/quest/app')));});
check('normal Android remains separate',()=>{assert(!phone.includes('com.oculus.supportedDevices'));assert(!phone.includes('com.oculus.intent.category.2D'));});
check('retired native XR bridge is not active',()=>{assert(!build.includes('XRBridgeActivity'));assert(!build.includes('WebXRCustomTabActivity'));assert(!web.includes('scheme=rantlistxr'));assert(!web.includes('fun.workwork.rantlist/.XRBridgeActivity'));});
check('Quest release installs and launches through ADB without hardcoded activity',()=>{assert(build.includes('devices -l'));assert(build.includes('install -r "$APK"'));assert(build.includes('shell monkey -p fun.workwork.rantlist -c android.intent.category.LAUNCHER 1'));assert(!build.includes('shell am start -W -n fun.workwork.rantlist/com.google.androidbrowserhelper.trusted.LauncherActivity'));});
check('Quest ADB parser recognizes a real space-delimited device row',()=>{
 const start=build.indexOf('install_connected_quest_devices() {'),end=build.indexOf('\n[[ "$(uname -s)" == Darwin ]]');
 assert(start>=0&&end>start);const fn=build.slice(start,end);
 const temp=fs.mkdtempSync('/tmp/rantlist-quest-adb-test.');const sdk=path.join(temp,'sdk'),pt=path.join(sdk,'platform-tools'),adb=path.join(pt,'adb'),apk=path.join(temp,'Rantlist.apk'),calls=path.join(temp,'calls');
 fs.mkdirSync(pt,{recursive:true});fs.writeFileSync(apk,'apk');
 fs.writeFileSync(adb,`#!/bin/bash\nset -e\nprintf '%s\\n' "$*" >> '${calls}'\nif [[ "\${1:-}" == devices && "\${2:-}" == -l ]]; then printf 'List of devices attached\\n2G0YC1ZF7L07MM    device product:eureka model:Quest_3 device:eureka transport_id:1\\n'; exit 0; fi\nif [[ "\${1:-}" == -s && "\${3:-}" == shell && "\${4:-}" == getprop ]]; then case "\${5:-}" in ro.product.manufacturer) echo Oculus;; ro.product.model) echo 'Quest 3';; ro.product.brand) echo oculus;; esac; exit 0; fi\nif [[ "\${1:-}" == -s && "\${3:-}" == install && "\${4:-}" == -r ]]; then echo Success; exit 0; fi\nif [[ "\${1:-}" == -s && "\${3:-}" == shell && "\${4:-}" == am ]]; then exit 0; fi\nif [[ "\${1:-}" == -s && "\${3:-}" == shell && "\${4:-}" == monkey ]]; then exit 0; fi\nexit 0\n`);fs.chmodSync(adb,0o755);
 const script=`set -Eeuo pipefail\nlog(){ :; }\n${fn}\nINSTALL_CONNECTED=1\nSDK_ROOT=${JSON.stringify(sdk)}\nAPP_VERSION=9.6.518\nBUILD_NUMBER=999\nAPK=${JSON.stringify(apk)}\ninstall_connected_quest_devices\n`;
 const r=cp.spawnSync('bash',['-c',script],{encoding:'utf8'});assert.strictEqual(r.status,0,r.stderr||r.stdout);const log=fs.readFileSync(calls,'utf8');assert(log.includes('-s 2G0YC1ZF7L07MM install -r '+apk),log);assert(log.includes('-s 2G0YC1ZF7L07MM shell monkey -p fun.workwork.rantlist -c android.intent.category.LAUNCHER 1'),log);fs.rmSync(temp,{recursive:true,force:true});
});
check('platform-targeted watcher releases remain supported',()=>{const target=read('.watch-release-platform').trim();assert(['all','macos','android','quest','pico','ios','windows','linux'].includes(target));const rel=read('scripts/release_and_deploy_homepage.sh');assert(rel.includes('PACKAGE_RELEASE_TARGET_FILE'));assert(rel.includes('macos|android|quest|pico|ios|windows|linux|all)'));assert(rel.includes('REQUESTED_PLATFORMS="$package_target"'));});
console.log(`Current Meta Quest packaging: ${n} checks passed.`);
