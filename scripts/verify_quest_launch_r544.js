#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');
let n=0;function check(x,f){f();n++;console.log('PASS '+x)}
const pkg=read('PACKAGE_VERSION.txt').trim(),gradle=read('mobile/quest/app/build.gradle'),manifest=read('mobile/quest/app/src/main/AndroidManifest.xml'),build=read('scripts/build_quest_release.sh');
check('Quest launch hotfix package is 0.1.297 or later',()=>{const p=pkg.split('.').map(Number);assert(p.length===3&&p.every(Number.isInteger));assert(p[0]>0||p[1]>1||(p[1]===1&&p[2]>=297))});
check('Quest uses Android Browser Helper artifact that supplies declared LauncherActivity',()=>{assert(gradle.includes("com.google.androidbrowserhelper:androidbrowserhelper:2.5.0"));assert(!gradle.includes('com.meta.androidbrowserhelper:androidbrowserhelper:2.5.0'));assert(manifest.includes('com.google.androidbrowserhelper.trusted.LauncherActivity'))});
check('Quest build validates LauncherActivity without pipefail/grep-q false failures',()=>{assert(build.includes("unzip -Z1 \"$APK_SRC\""));assert(build.includes('launcher_descriptor'));assert(build.includes('grep -F \"$launcher_descriptor\" >/dev/null'));assert(!build.includes("grep -Fq 'Lcom/google/androidbrowserhelper/trusted/LauncherActivity;'"));assert(build.includes('refusing to publish a non-launchable APK'))});
check('Quest remains 2D TWA so in-page requestSession can enter WebXR',()=>{assert(manifest.includes('horizonos.pwa.APP_MODE'));assert(manifest.includes('android:value="2D"'));assert(manifest.includes('com.oculus.intent.category.2D'))});
console.log(`Client Quest launch regression r544: ${n} checks passed.`);
