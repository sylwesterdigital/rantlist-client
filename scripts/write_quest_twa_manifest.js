#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
function die(m){ console.error(`ERROR: ${m}`); process.exit(1); }
const args={};
for(let i=2;i<process.argv.length;i++){ const k=process.argv[i]; if(k.startsWith('--')) args[k.slice(2)]=process.argv[++i]||''; }
for(const k of ['template','output','version','build','keystore','alias']) if(!args[k]) die(`--${k} is required`);
if(!/^\d+\.\d+\.\d+$/.test(args.version)) die('invalid semantic version');
if(!/^[1-9]\d*$/.test(args.build)) die('invalid build number');
const manifest=JSON.parse(fs.readFileSync(path.resolve(args.template),'utf8'));
manifest.appVersion=args.version;
manifest.appVersionCode=Number(args.build);
manifest.signingKey={path:path.resolve(args.keystore),alias:args.alias};
manifest.packageId='fun.workwork.rantlist';
manifest.host='rantlist.me';
manifest.webManifestUrl='https://rantlist.me/manifest.webmanifest';
manifest.fullScopeUrl='https://rantlist.me/';
manifest.startUrl='/?rantlistPwa=1';
manifest.display='standalone';
manifest.orientation='landscape';
manifest.isMetaQuest=true;
manifest.horizonOSAppMode='immersive';
fs.mkdirSync(path.dirname(path.resolve(args.output)),{recursive:true});
fs.writeFileSync(path.resolve(args.output),JSON.stringify(manifest,null,2)+'\n');
console.log(`Quest Bubblewrap manifest: ${manifest.packageId} ${manifest.appVersion} (${manifest.appVersionCode}) ${manifest.horizonOSAppMode}`);
