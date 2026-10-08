#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');
const config=JSON.parse(read('mobile/pico/webapp-release.json'));
const build=read('scripts/build_pico_release.sh');
const release=read('scripts/release_and_deploy_homepage.sh');
const publish=read('scripts/publish_github_release.sh');
const homepage=read('scripts/deploy_homepage.sh');
const pkg=read('PACKAGE_VERSION.txt').trim().split('.').map(Number);
let n=0;function check(name,fn){fn();n++;console.log('PASS '+name)}
check('client package is 0.1.306 or later',()=>assert(pkg.length===3&&pkg.every(Number.isInteger)&&(pkg[0]>0||pkg[1]>1||(pkg[1]===1&&pkg[2]>=306))));
check('PICO target is URL-based Web App',()=>{assert.equal(config.platform,'pico');assert.equal(config.kind,'web-app');assert.equal(config.appUrl,'https://rantlist.me/');assert.equal(config.manifestUrl,'https://rantlist.me/manifest.webmanifest');assert.equal(config.distribution.developerPortalType,'Web App');assert.equal(config.distribution.binaryRequired,false)});
check('PICO build validates live app and manifest and creates GitHub artifact',()=>{assert(build.includes('curl --fail'));assert(build.includes('manifest.webmanifest'));assert(build.includes('-pico-webapp.zip'));assert(build.includes('-pico-SHA256.txt'));assert(build.includes('PICO Web App manifest contract passed'));assert(!/gradle|assembleRelease|\.apk|\.aab/.test(build))});
check('PICO is a first-class release platform',()=>{assert(release.includes('macos android quest pico ios windows linux'));assert(release.includes('--pico'));assert(release.includes('build_pico_release.sh'));assert(release.includes('pico-SHA256.txt'))});
check('GitHub publisher carries PICO Web App bundle',()=>{assert(publish.includes('-pico-webapp.zip'));assert(publish.includes('-pico-SHA256.txt'));assert(publish.includes('PICO: Web App'))});
check('homepage resolves PICO release and exposes PICO Web App button',()=>{assert(homepage.includes("kind=='pico_webapp'"));assert(homepage.includes("PICO Web App"));assert(homepage.includes("https://rantlist.me/"))});
check('watcher package targets PICO only for this integration release',()=>assert.equal(read('.watch-release-platform').trim(),'pico'));
console.log(`PICO Web App release integration: ${n} checks passed.`);
