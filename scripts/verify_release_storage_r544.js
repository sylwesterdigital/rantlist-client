#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..');
const read=n=>fs.readFileSync(path.join(root,n),'utf8');
let n=0; const check=(name,fn)=>{fn();n++;console.log('PASS '+name)};
const pkg=read('PACKAGE_VERSION.txt').trim();
const rel=read('scripts/release_and_deploy_homepage.sh');
check('client storage diagnostics package is 0.1.295 or later',()=>{const p=pkg.split('.').map(Number);assert(p.length===3&&p.every(Number.isInteger));assert(p[0]>0||p[1]>1||(p[1]===1&&p[2]>=295))});
check('release preflight cleans only project-local generated build roots',()=>{assert(rel.includes('cleanup_local_build_space(){'));for(const x of ['.macos-build','.ios-build','mobile/android/app/build','mobile/quest/app/build'])assert(rel.includes(x));assert(rel.includes('Never touches system caches'))});
check('release no longer hard-stops at the old unconditional 2GB threshold',()=>{assert(!rel.includes('if ($4 < 2097152)'));assert(rel.includes('check_local_release_space'));assert(rel.includes('512*1024'))});
check('verified local builds release temporary space before the next platform',()=>{assert(rel.includes('cleanup_after_local_platform "$platform"'))});
check('local storage failures are explicit and red',()=>{for(const x of ['RELEASE STOPPED — NOT ENOUGH STORAGE','LOW DISK SPACE','Available:','Required minimum: 512 MiB','\\033[1;31m'])assert(rel.includes(x))});
check('desktop worker storage failures are explicit and red',()=>{const worker=read('scripts/check_desktop_build_worker.sh');for(const x of ['DESKTOP BUILD STOPPED — NOT ENOUGH STORAGE','Available:','Required minimum: 5.00 GiB','\\033[1;31m'])assert(worker.includes(x))});
check('local storage is checked before remote desktop worker',()=>{assert(rel.indexOf('check_local_release_space')<rel.lastIndexOf('check_desktop_build_worker.sh'))});
console.log(`Client release disk-space recovery r544: ${n} regression groups passed.`);
