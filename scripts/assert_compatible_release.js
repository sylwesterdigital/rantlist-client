#!/usr/bin/env node
'use strict';
const assert=require('node:assert/strict');
function versionAtLeast(actual,minimum){
  const parse=(value)=>{const match=/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.exec(String(value));assert(match,`Invalid numeric version ${value}`);const parts=match.slice(1).map(Number);assert(parts.every(Number.isSafeInteger));return parts;};
  const current=parse(actual),floor=parse(minimum);
  for(let i=0;i<3;i++){if(current[i]>floor[i])return true;if(current[i]<floor[i])return false;}return true;
}
function revisionAtLeast(actual,minimum){const match=/^rantlist-deploy-r([1-9]\d*)$/.exec(String(actual));assert(match,`Invalid revision ${actual}`);return Number(match[1])>=minimum;}
module.exports={versionAtLeast,revisionAtLeast};
