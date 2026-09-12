#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const iosRoot = process.argv[2];
if (!iosRoot) {
  console.error('Usage: make_ios_push_only_project.js <copied-mobile-ios-dir>');
  process.exit(2);
}

const projectPath = path.join(iosRoot, 'Rantlist.xcodeproj', 'project.pbxproj');
const entitlementsPath = path.join(iosRoot, 'Rantlist', 'RantlistPushOnly.entitlements');
let project = fs.readFileSync(projectPath, 'utf8');

function replaceRequired(label, pattern, replacement, expected = 1) {
  const matches = project.match(pattern);
  const count = matches ? matches.length : 0;
  if (count !== expected) {
    throw new Error(`${label}: expected ${expected} project match(es), found ${count}`);
  }
  project = project.replace(pattern, replacement);
}

// Remove the extension from the containing app's archive graph. The extension
// target remains in this temporary project copy, but it is neither depended on
// nor embedded, so Xcode signs only the main app.
replaceRequired(
  'Share Extension embed entry',
  /files = \(A10000000000000000000004 \/\* RantlistShare\.appex in Embed App Extensions \*\/,[ \t]*\);/g,
  'files = ();'
);
replaceRequired(
  'Share Extension target dependency',
  /dependencies = \(AB0000000000000000000001 \/\* PBXTargetDependency \*\/,[ \t]*\);/g,
  'dependencies = ();'
);

// In the temporary fallback project, provisioning must not request an App
// Group. Push Notifications remains enabled for the containing app.
{
  const capability = 'com.apple.ApplicationGroups.iOS = {enabled = 1;};';
  const count = project.split(capability).length - 1;
  if (count !== 2) {
    throw new Error(`App Groups capability metadata: expected 2 project match(es), found ${count}`);
  }
  project = project.split(capability).join('');
}
replaceRequired(
  'Main-app entitlements build setting',
  /CODE_SIGN_ENTITLEMENTS = Rantlist\/Rantlist\.entitlements;/g,
  'CODE_SIGN_ENTITLEMENTS = Rantlist/RantlistPushOnly.entitlements;',
  2
);

fs.writeFileSync(projectPath, project);
fs.writeFileSync(entitlementsPath, `<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n    <key>aps-environment</key>\n    <string>$(APS_ENVIRONMENT)</string>\n</dict>\n</plist>\n`);

console.log(`Prepared temporary push-only iOS project: ${iosRoot}`);
