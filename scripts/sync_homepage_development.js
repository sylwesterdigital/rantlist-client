#!/usr/bin/env node
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

function fail(message){ console.error(`ERROR: ${message}`); process.exit(1); }
function esc(value){ return String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch])); }
function extractArray(source){
  const marker = 'const DEVELOPMENT_RELEASES = Object.freeze(';
  const start = source.indexOf(marker);
  if (start < 0) fail('server.js does not contain DEVELOPMENT_RELEASES.');
  const open = source.indexOf('[', start + marker.length);
  if (open < 0) fail('DEVELOPMENT_RELEASES array opening bracket missing.');
  let depth=0, quote='', escaped=false, lineComment=false, blockComment=false;
  for(let i=open;i<source.length;i++){
    const ch=source[i], next=source[i+1] || '';
    if(lineComment){ if(ch==='\n') lineComment=false; continue; }
    if(blockComment){ if(ch==='*' && next==='/'){ blockComment=false; i++; } continue; }
    if(quote){ if(escaped){ escaped=false; continue; } if(ch==='\\'){ escaped=true; continue; } if(ch===quote){ quote=''; } continue; }
    if(ch==='/' && next==='/'){ lineComment=true; i++; continue; }
    if(ch==='/' && next==='*'){ blockComment=true; i++; continue; }
    if(ch==="'" || ch==='"' || ch==='`'){ quote=ch; continue; }
    if(ch==='[') depth++;
    else if(ch===']'){
      depth--;
      if(depth===0) return source.slice(open,i+1);
    }
  }
  fail('DEVELOPMENT_RELEASES array closing bracket missing.');
}

const root = path.resolve(__dirname, '..');
const sourceRoot = path.resolve(process.argv[2] || process.env.SOURCE_PROJECT || '/Users/smielniczuk/Documents/works/stage/chat');
const serverFile = path.join(sourceRoot,'server.js');
const homepageFile = path.join(root,'homepage','index.html');
if(!fs.existsSync(serverFile)) fail(`Missing ${serverFile}`);
if(!fs.existsSync(homepageFile)) fail(`Missing ${homepageFile}`);
let releases;
try {
  const literal = extractArray(fs.readFileSync(serverFile,'utf8'));
  releases = vm.runInNewContext(`(${literal})`, Object.create(null), {timeout:1000});
} catch(error){ fail(`Could not read DEVELOPMENT_RELEASES: ${error.message}`); }
if(!Array.isArray(releases) || releases.length===0) fail('DEVELOPMENT_RELEASES is empty.');
const limit = Math.max(1, Math.min(30, Number(process.env.HOMEPAGE_RELEASE_LIMIT || 12) || 12));
const selected = releases.slice(0,limit);
for(const release of selected){
  if(!/^\d+\.\d+\.\d+$/.test(String(release.version||''))) fail('Development release has invalid version.');
  if(!/^rantlist-deploy-r\d+$/.test(String(release.revision||''))) fail('Development release has invalid revision.');
}
const blocks = selected.map((release) => {
  const date = String(release.releasedAt || release.date || '').slice(0,10);
  const detail = Array.isArray(release.changes) ? release.changes : (Array.isArray(release.notes) ? release.notes : []);
  const list = detail.slice(0,4).map(x=>`<li>${esc(x)}</li>`).join('');
  return `<section class="release-note" data-development-release="${esc(release.revision)}" aria-label="${esc(release.title || 'Rantlist update')}"><h2>${esc(release.title || 'Rantlist update')}</h2><p><strong>Rantlist ${esc(release.version)} · ${esc(release.revision)}${date ? ` · ${esc(date)}` : ''}</strong> — ${esc(release.summary || '')}</p>${list ? `<ul>${list}</ul>` : ''}</section>`;
}).join('\n');
const startMarker='<!-- DEVELOPMENT_RELEASES_START -->';
const endMarker='<!-- DEVELOPMENT_RELEASES_END -->';
let html = fs.readFileSync(homepageFile,'utf8');
const marked = html.includes(startMarker) && html.includes(endMarker);
if(marked){
  const re = new RegExp(`${startMarker}[\\s\\S]*?${endMarker}`);
  html = html.replace(re, `${startMarker}\n${blocks}\n${endMarker}`);
} else {
  // Migrate the old hand-maintained release-note tail once, then retain markers forever.
  html = html.replace(/(?:\n<section class="release-note"[\s\S]*?<\/section>)+\n<\/main>/, `\n${startMarker}\n${blocks}\n${endMarker}\n</main>`);
  if(!html.includes(startMarker)) fail('Could not locate homepage release-note insertion point.');
}
fs.writeFileSync(homepageFile,html);
console.log(`Homepage development log synchronized from #development source: ${selected.length} releases; latest ${selected[0].version} / ${selected[0].revision}.`);
