#!/usr/bin/env node
'use strict';
const {spawnSync}=require('child_process'),path=require('path');
const r=spawnSync(process.execPath,[path.join(__dirname,'verify_quest_packaging_current.js')],{stdio:'inherit'});
process.exit(r.status===null?1:r.status);
