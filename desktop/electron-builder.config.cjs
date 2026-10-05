'use strict';
const fs = require('fs');
const path = require('path');

const desktopRoot = __dirname;
const repoRoot = path.resolve(desktopRoot, '..');
const version = fs.readFileSync(path.join(repoRoot, 'VERSION.txt'), 'utf8').trim();
if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error(`Invalid VERSION.txt: ${version}`);
const output = process.env.RANTLIST_DESKTOP_OUTPUT || path.join(repoRoot, '.desktop-build', 'dist');

module.exports = {
  appId: 'fun.workwork.rantlist',
  productName: 'Rantlist',
  asar: true,
  npmRebuild: false,
  extraMetadata: { version },
  directories: { output },
  files: ['src/**/*', 'assets/**/*', 'package.json'],
  linux: {
    target: ['AppImage', 'deb'],
    category: 'Network',
    synopsis: 'Rantlist desktop chat client',
    description: 'Rantlist desktop client for Windows and Linux',
    maintainer: 'Rantlist <noreply@rantlist.me>',
    vendor: 'Rantlist',
    executableName: 'rantlist',
    icon: 'assets/linux',
    desktop: {
      entry: {
        Name: 'Rantlist',
        Comment: 'Rantlist chat client',
        Categories: 'Network;Chat;InstantMessaging;',
        StartupWMClass: 'fun.workwork.rantlist',
        Terminal: false,
        Type: 'Application'
      }
    }
  },
  appImage: {
    artifactName: `Rantlist-v${version}-linux-x86_64.\${ext}`
  },
  deb: {
    maintainer: 'Rantlist <noreply@rantlist.me>',
    artifactName: `rantlist_${version}_amd64.\${ext}`
  },
  win: {
    executableName: 'Rantlist',
    icon: 'assets/icon.ico',
    signExecutable: false,
    verifyUpdateCodeSignature: false
  }
};
