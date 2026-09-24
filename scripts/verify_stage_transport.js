#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=name=>fs.readFileSync(path.join(root,name),'utf8');
const web=read('web/index.html');
const meta=JSON.parse(read('web/client-source.json'));
assert.equal(meta.sourceVersion,read('VERSION.txt').trim());
assert.equal(meta.sourceRevision,'rantlist-deploy-r383');
assert(web.includes('String(message.detail).slice(0,60)'), 'native browser must expose bounded cut rejection detail');
assert(web.includes('Opening cut was not shared:'), 'native browser must distinguish failed cut relay');
assert(web.includes("case 'stage.world.paint.state':"),'native browser must restore per-object paint after remote baseline');
assert(web.includes('stagePendingPaintAfterSnapshot'),'native browser must replay painted new objects only after a snapshot ACK');
assert(web.includes("case 'stage.world.edit.reject':"),'style event rejections must remain visible');
console.log('Native web Stage cut, style and paint transport regression passed (self-contained client package).');
