#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..');
const deploy=fs.readFileSync(path.join(root,'scripts/deploy_homepage.sh'),'utf8');
const release=fs.readFileSync(path.join(root,'scripts/release_and_deploy_homepage.sh'),'utf8');
const contentDeploy=fs.readFileSync(path.join(root,'scripts/deploy_homepage_content.sh'),'utf8');
const pkg=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
function check(name,fn){fn();console.log('PASS '+name);}
check('client package is r533 content-ownership release or later',()=>{const v=pkg.split('.').map(Number);assert.equal(v[0],0);assert.equal(v[1],1);assert.ok(v[2]>=278);});
check('full homepage deploy protects public content JSON',()=>{for(const f of ['content.json','content.json.gz','content.json.br']) assert(deploy.includes(`--exclude='${f}'`),f);});
check('full release commit excludes operator content',()=>assert(release.includes("' :(exclude)homepage/content.json'")===false && release.includes("':(exclude)homepage/content.json'")));
check('operator content does not participate in release whitespace check',()=>assert(release.includes("git diff --check -- . ':(exclude)web/**' ':(exclude)homepage/content.json'")));
check('dedicated content deploy remains the sole uploader',()=>{assert(contentDeploy.includes('Update homepage/content.json only')); assert(contentDeploy.includes('"$TMP/"'));});
console.log('Homepage content ownership: 5 checks passed.');
