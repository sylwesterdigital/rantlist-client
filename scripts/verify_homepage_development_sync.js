#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');let n=0;
function check(name,fn){fn();n++;console.log('PASS '+name)}
const source=JSON.parse(read('web/client-source.json'));
const html=read('homepage/index.html'),sync=read('scripts/sync_homepage_development.js'),release=read('scripts/release_and_deploy_homepage.sh');
check('homepage has generated development markers',()=>{assert(html.includes('<!-- DEVELOPMENT_RELEASES_START -->'));assert(html.includes('<!-- DEVELOPMENT_RELEASES_END -->'))});
check('homepage latest release matches synchronized #development source',()=>{assert(html.includes(`data-development-release="${source.sourceRevision}"`));assert(html.includes(`Rantlist ${source.sourceVersion}`))});
check('release workflow regenerates homepage notes from stage/chat',()=>{const a=release.indexOf('sync_from_stage.sh'),b=release.indexOf('sync_homepage_development.js'),c=release.indexOf('verify_client_repo.sh',a);assert(a>=0&&b>a&&c>b)});
check('sync script reads DEVELOPMENT_RELEASES',()=>{assert(sync.includes('const DEVELOPMENT_RELEASES = Object.freeze('));assert(sync.includes('HOMEPAGE_RELEASE_LIMIT'));assert(sync.includes('data-development-release'))});
console.log(`Homepage #development synchronization: ${n} regression groups passed.`);
