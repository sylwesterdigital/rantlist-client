#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'web/index.html'),'utf8'),source=require('../web/client-source.json'),pkg=fs.readFileSync(path.join(root,'PACKAGE_VERSION.txt'),'utf8').trim();
assert.ok(/^0\.1\.(?:25[3-9]|2[6-9][0-9]|[3-9][0-9]{2,})$/.test(pkg));const parts=String(source.sourceVersion).split('.').map(Number);assert.equal(parts[0],9);assert.equal(parts[1],6);assert.ok(parts[2]>=455);assert.ok(Number(String(source.sourceRevision).match(/r(\d+)$/)?.[1]||0)>=483);
assert.match(html,/stage-frame-media-preview\{[^}]*aspect-ratio:var\(--stage-frame-media-aspect\)[^}]*min-height:112px/);
assert.match(html,/img\.naturalWidth\/img\.naturalHeight/);
assert.match(html,/sourceAspect:Number\.isFinite\(sourceAspect\)/);
assert.match(html,/grid-template-columns:repeat\(auto-fill,minmax\(170px,1fr\)\)/);
console.log('PASS client r483 Surface Frame channel-media aspect previews');
