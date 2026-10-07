#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'..'),read=n=>fs.readFileSync(path.join(root,n),'utf8');let n=0;
function check(name,fn){fn();n++;console.log('PASS '+name)}
const pkg=read('PACKAGE_VERSION.txt').trim();
const deploy=read('scripts/deploy_homepage.sh'),release=read('scripts/release_and_deploy_homepage.sh'),contentDeploy=read('scripts/deploy_homepage_content.sh');
check('client package is r543 content-ownership release or later',()=>assert(Number(pkg.split('.').at(-1))>=292));
check('full homepage deploy publishes operator content JSON',()=>{assert(!deploy.includes("--exclude='content.json'"));assert(deploy.includes('cmp -s "$PROJECT_DIR/content.json" "$BUILD_DIR/content.json"'));assert(deploy.includes('Public content.json does not match the local operator content'))});
check('full release protects local operator content across sync and git update',()=>{assert(release.includes('protect_operator_content'));assert(release.includes('restore_operator_content'));assert(release.includes('sync_homepage_development.js'))});
check('full release commit excludes operator content',()=>assert(release.includes("':(exclude)homepage/content.json'")));
check('operator content does not participate in release whitespace check',()=>assert(release.includes("git diff --check -- . ':(exclude)web/**' ':(exclude)homepage/content.json'")));
check('dedicated content deploy remains available',()=>{assert(contentDeploy.includes('Update homepage/content.json only')); assert(contentDeploy.includes('Public content.json does not match the local file after deployment.'))});
console.log(`Homepage operator content ownership r543: ${n} regression groups passed.`);
