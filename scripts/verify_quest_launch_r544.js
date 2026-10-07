#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert'),cp=require('child_process');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');
let n=0;function check(x,f){f();n++;console.log('PASS '+x)}
const pkg=read('PACKAGE_VERSION.txt').trim(),gradle=read('mobile/quest/app/build.gradle'),manifest=read('mobile/quest/app/src/main/AndroidManifest.xml'),build=read('scripts/build_quest_release.sh');
check('Quest launch/install hotfix package is 0.1.301 or later',()=>{const p=pkg.split('.').map(Number);assert(p.length===3&&p.every(Number.isInteger));assert(p[0]>0||p[1]>1||(p[1]===1&&p[2]>=301))});
check('Quest uses Android Browser Helper artifact that supplies declared LauncherActivity',()=>{assert(gradle.includes("com.google.androidbrowserhelper:androidbrowserhelper:2.5.0"));assert(!gradle.includes('com.meta.androidbrowserhelper:androidbrowserhelper:2.5.0'));assert(manifest.includes('com.google.androidbrowserhelper.trusted.LauncherActivity'))});
check('Quest build validates LauncherActivity without pipefail/grep-q false failures',()=>{assert(build.includes("unzip -Z1 \"$APK_SRC\""));assert(build.includes('launcher_descriptor'));assert(build.includes('grep -F "$launcher_descriptor" >/dev/null'));assert(!build.includes("grep -Fq 'Lcom/google/androidbrowserhelper/trusted/LauncherActivity;'"));assert(build.includes('refusing to publish a non-launchable APK'))});
check('Quest release automatically installs and launches on a connected authorised Quest',()=>{assert(build.includes('RANTLIST_QUEST_INSTALL_CONNECTED:-1'));assert(build.includes('install_connected_quest_devices'));assert(build.includes('install -r "$APK"'));assert(build.includes('shell am start -W -n fun.workwork.rantlist/com.google.androidbrowserhelper.trusted.LauncherActivity'));assert(build.includes('devices -l'));assert(build.includes('while IFS= read -r line'));assert(build.includes('No ADB USB device is visible'))});
check('Quest install function declaration is executable, not escaped text',()=>{assert(!build.includes('\\ninstall_connected_quest_devices() {'));const start=build.indexOf('install_connected_quest_devices() {'),end=build.indexOf('\n[[ "$(uname -s)" == Darwin ]]');assert(start>=0&&end>start);const fn=build.slice(start,end);const r=cp.spawnSync('bash',['-c',`set -Eeuo pipefail\nlog(){ :; }\n${fn}\nINSTALL_CONNECTED=0\ninstall_connected_quest_devices\n`],{encoding:'utf8'});assert.strictEqual(r.status,0,`Quest install function failed to execute: ${r.stderr||r.stdout}`)});
check('Quest ADB parser actually recognizes and installs a space-delimited Quest 3',()=>{
  const start=build.indexOf('install_connected_quest_devices() {'),end=build.indexOf('\n[[ "$(uname -s)" == Darwin ]]');
  assert(start>=0&&end>start);
  const fn=build.slice(start,end);
  const temp=fs.mkdtempSync('/tmp/rantlist-quest-adb-test.');
  const sdk=path.join(temp,'sdk'),pt=path.join(sdk,'platform-tools'),adb=path.join(pt,'adb'),apk=path.join(temp,'Rantlist.apk'),calls=path.join(temp,'calls');
  fs.mkdirSync(pt,{recursive:true});fs.writeFileSync(apk,'apk');
  fs.writeFileSync(adb,`#!/bin/bash
set -e
printf '%s\\n' "$*" >> '${calls}'
if [[ "\${1:-}" == devices && "\${2:-}" == -l ]]; then printf 'List of devices attached\\nQUEST123\\tdevice product:eureka model:Quest_3 device:eureka transport_id:1\\n'; exit 0; fi
if [[ "\${1:-}" == -s && "\${3:-}" == shell && "\${4:-}" == getprop ]]; then case "\${5:-}" in ro.product.manufacturer) echo Oculus;; ro.product.model) echo 'Quest 3';; ro.product.brand) echo oculus;; esac; exit 0; fi
if [[ "\${1:-}" == -s && "\${3:-}" == install && "\${4:-}" == -r ]]; then echo Success; exit 0; fi
if [[ "\${1:-}" == -s && "\${3:-}" == shell && "\${4:-}" == am ]]; then exit 0; fi
exit 0
`);
  fs.chmodSync(adb,0o755);
  const script=`set -Eeuo pipefail\nlog(){ :; }\n${fn}\nINSTALL_CONNECTED=1\nSDK_ROOT=${JSON.stringify(sdk)}\nAPP_VERSION=9.6.516\nBUILD_NUMBER=999\nAPK=${JSON.stringify(apk)}\ninstall_connected_quest_devices\n`;
  const r=cp.spawnSync('bash',['-c',script],{encoding:'utf8'});
  assert.strictEqual(r.status,0,r.stderr||r.stdout);
  const log=fs.readFileSync(calls,'utf8');
  assert(log.includes('-s QUEST123 install -r '+apk),log);
  assert(log.includes('-s QUEST123 shell am start -W -n fun.workwork.rantlist/com.google.androidbrowserhelper.trusted.LauncherActivity'),log);
  fs.rmSync(temp,{recursive:true,force:true});
});
check('Quest hotfix package narrows watcher all-platform release to Quest only',()=>{
  const rel=read('scripts/release_and_deploy_homepage.sh');
  assert.strictEqual(read('.watch-release-platform').trim(),'quest');
  assert(rel.includes('PACKAGE_RELEASE_TARGET_FILE'));
  assert(rel.includes('Package release target: $package_target only; skipping unrelated platform builds.'));
  assert(rel.includes('REQUESTED_PLATFORMS="$package_target"'));
});
check('Quest remains 2D TWA so in-page requestSession can enter WebXR',()=>{assert(manifest.includes('horizonos.pwa.APP_MODE'));assert(manifest.includes('android:value="2D"'));assert(manifest.includes('com.oculus.intent.category.2D'))});
console.log(`Client Quest launch regression r544: ${n} checks passed.`);
