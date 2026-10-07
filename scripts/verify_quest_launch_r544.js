#!/usr/bin/env node
'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert'),{spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..');
const source=JSON.parse(fs.readFileSync(path.join(root,'web/client-source.json'),'utf8'));
const rev=Number(String(source.sourceRevision||'').match(/r(\d+)$/)?.[1]||0);
assert(rev>=544,'Quest client source must remain r544-compatible or later');
const r=spawnSync(process.execPath,[path.join(__dirname,'verify_quest_packaging_current.js')],{stdio:'inherit'});
process.exit(r.status===null?1:r.status);
