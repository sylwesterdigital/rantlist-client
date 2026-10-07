#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..');const read=n=>fs.readFileSync(path.join(root,n),'utf8');
const pkg=read('PACKAGE_VERSION.txt').trim(),source=JSON.parse(read('web/client-source.json')),html=read('web/index.html');
const manifest=read('mobile/android/app/src/main/AndroidManifest.xml'),android=read('mobile/android/app/src/main/java/fun/workwork/rantlist/MainActivity.java');let n=0;
function check(name,fn){fn();n++;console.log('PASS '+name);}
check('client r534 metadata is current or later',()=>{const p=pkg.split('.').map(Number),s=source.sourceVersion.split('.').map(Number),r=Number(String(source.sourceRevision).match(/r(\d+)$/)?.[1]);assert.equal(p[0],0);assert.equal(p[1],1);assert.ok(p[2]>=279);assert.equal(s[0],9);assert.equal(s[1],6);assert.ok(s[2]>=506);assert.ok(r>=534);});
check('Quest packaging remains separate from the normal Android phone manifest',()=>{const p=pkg.split('.').map(Number);if(p[2]>=283){assert(!manifest.includes('com.oculus.supportedDevices'));assert(!manifest.includes('com.oculus.intent.category.2D'));assert(fs.existsSync(path.join(root,'mobile/quest/twa-manifest.template.json')));}else{assert(manifest.includes('com.oculus.supportedDevices'));assert(manifest.includes('com.oculus.intent.category.2D'));}});
check('Android XR bridge is trusted and does not pretend WebView is native immersive',()=>{assert(android.includes('installXrChannel(view)'));assert(android.includes('rantlist-native-xr-channel-v1'));assert(android.includes('handleXrMessage'));assert(android.includes('response.put("nativeImmersive", false)'));assert(android.includes('Intent.ACTION_VIEW'));assert(android.includes('if (!isTrusted(target))'));});
check('browser client relays Stage XR fallback through native bridge',()=>{assert(html.includes('rantlist-native-xr-channel-v1'));assert(html.includes("if(data.event==='native-xr-open')"));assert(html.includes("nativeXrRequest('openBrowser',url)"));});
check('Avatar Lab source chooser keeps icon labels',()=>{assert(html.includes('.avatar-lab-source-menu button span:not(.icon){display:inline!important'));assert(html.includes('const menuRect=menu.getBoundingClientRect()'));});
check('r533 content ownership verifier is release-forward',()=>{const old=read('scripts/verify_homepage_content_ownership.js');assert(old.includes('v[2]>=278'));});
console.log(`Client Quest XR + source chooser r534: ${n} regression groups passed.`);
