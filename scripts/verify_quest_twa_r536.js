#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
const fail = (m) => { console.error(`FAIL ${m}`); process.exit(1); };
const pass = (m) => console.log(`PASS ${m}`);
const expect = (c, m) => { if (!c) fail(m); pass(m); };

const pkgVersion = read('PACKAGE_VERSION.txt').trim();
const clientVersion = read('VERSION.txt').trim();
const source = JSON.parse(read('web/client-source.json'));
const phoneGradle = read('mobile/android/app/build.gradle');
const phoneManifest = read('mobile/android/app/src/main/AndroidManifest.xml');
const phoneMain = read('mobile/android/app/src/main/java/fun/workwork/rantlist/MainActivity.java');
const questGradle = read('mobile/quest/app/build.gradle');
const questRootGradle = read('mobile/quest/build.gradle');
const questProperties = read('mobile/quest/gradle.properties');
const questManifest = read('mobile/quest/app/src/main/AndroidManifest.xml');
const questStrings = read('mobile/quest/app/src/main/res/values/strings.xml');
const questBuild = read('scripts/build_quest_release.sh');
const releaseFlow = read('scripts/release_and_deploy_homepage.sh');
const githubPublish = read('scripts/publish_github_release.sh');
const homepageDeploy = read('scripts/deploy_homepage.sh');

function versionAtLeast(actual, minimum) {
  const a = actual.split('.').map(Number), b = minimum.split('.').map(Number);
  for (let i = 0; i < Math.max(a.length, b.length); i += 1) {
    const av = a[i] || 0, bv = b[i] || 0;
    if (av !== bv) return av > bv;
  }
  return true;
}

expect(versionAtLeast(pkgVersion, '0.1.282') && versionAtLeast(clientVersion, '9.6.508') && source.sourceVersion === clientVersion,
  'split Android/Quest client metadata is current');

expect(!/androidbrowserhelper/i.test(phoneGradle) && !phoneManifest.includes('com.google.androidbrowserhelper.trusted.LauncherActivity') && phoneMain.includes('WebView'),
  'normal Android phone APK remains the native WebView client');

expect(/com\.meta\.androidbrowserhelper:androidbrowserhelper:2\.5\.0/.test(questGradle) && /android\.useAndroidX=true/.test(questProperties),
  'Quest-only project uses Meta Android Browser Helper with AndroidX enabled');

expect(/compileSdk 35/.test(questGradle) && /targetSdk 35/.test(questGradle) && /8\.7\.3/.test(questRootGradle),
  'Quest project stays isolated on the existing API 35 / AGP 8.7.3 toolchain');

expect(questManifest.includes('android:name="horizonos.pwa.APP_MODE" android:value="2D"') &&
       questManifest.includes('com.google.androidbrowserhelper.trusted.LauncherActivity') &&
       questManifest.includes('android:exported="true"') &&
       questManifest.includes('com.oculus.intent.category.2D') &&
       !questManifest.includes('com.oculus.intent.category.VR'),
  'Quest APK is a dedicated verified 2D TWA package');

expect(questStrings.includes('https://rantlist.me/') && questStrings.includes('delegate_permission/common.handle_all_urls') && questStrings.includes('"site":"https://rantlist.me"'),
  'Quest TWA origin binding remains rantlist.me');

expect(questBuild.includes('mobile/quest') && questBuild.includes('-quest.apk') && questBuild.includes('-quest.aab'),
  'Quest build produces separately named APK and AAB artifacts');

expect(releaseFlow.includes('android quest ios macos') && releaseFlow.includes('build_quest_release.sh') && releaseFlow.includes('${base}-quest.apk'),
  'release orchestrator builds and validates Quest separately from Android');

expect(githubPublish.includes('${BASE}-quest.apk') && githubPublish.includes('${BASE}-quest.aab') && githubPublish.includes('${BASE}-quest-SHA256.txt'),
  'GitHub release publisher uploads Quest APK/AAB and checksum');

expect(homepageDeploy.includes("kind=='quest_apk'") && homepageDeploy.includes("button('quest_apk','Meta Quest APK'"),
  'homepage release resolver exposes a Meta Quest download button');

console.log('Client split Android phone + Quest TWA r536: 10 regression groups passed.');
