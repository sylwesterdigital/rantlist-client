#!/usr/bin/env node
'use strict';
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
function read(rel){ return fs.readFileSync(path.join(root, rel), 'utf8'); }
function assert(ok,msg){ if(!ok){ console.error(`FAIL ${msg}`); process.exit(1); } console.log(`PASS ${msg}`); }
const required = [
  'desktop/package.json','desktop/electron-builder.config.cjs','desktop/src/main.js','desktop/assets/icon.png','desktop/assets/icon.ico',
  'desktop/installer/windows.nsi','scripts/desktop_build_common.sh','scripts/build_linux_release.sh','scripts/build_windows_release.sh','scripts/build_desktop_releases.sh',
  'scripts/desktop_remote_common.sh','scripts/check_desktop_build_worker.sh','scripts/build_desktop_remote.sh','scripts/validate_desktop_remote_artifacts.sh','scripts/fetch_desktop_remote_artifacts.sh','scripts/cleanup_desktop_remote_release.sh'
];
for(const rel of required) assert(fs.existsSync(path.join(root,rel)), `${rel} exists`);
const main = read('desktop/src/main.js');
assert(/nodeIntegration:\s*false/.test(main), 'remote Rantlist page has Node integration disabled');
assert(/contextIsolation:\s*true/.test(main), 'renderer context isolation is enabled');
assert(/sandbox:\s*true/.test(main), 'renderer sandbox is enabled');
assert(/webSecurity:\s*true/.test(main), 'web security remains enabled');
assert(/ALLOWED_HOSTS = new Set\(\['rantlist\.me', 'www\.rantlist\.me'\]\)/.test(main), 'desktop navigation is allow-listed to Rantlist HTTPS hosts');
const common = read('scripts/desktop_build_common.sh');
assert(/\[\[ "\$\(id -u\)" -ne 0 \]\]/.test(common), 'desktop builds refuse root execution');
assert(common.includes('/srv/rantlist-build'), 'desktop builds default to the dedicated build workspace');
for(const rel of ['scripts/desktop_build_common.sh','scripts/build_linux_release.sh','scripts/build_windows_release.sh','scripts/build_desktop_releases.sh']){
  const text = read(rel);
  assert(!/\b(?:apt|apt-get|systemctl|service|snap|docker|sudo)\b/.test(text), `${rel} does not modify system packages/services or invoke Docker/sudo`);
}
const builderConfig = require(path.join(root, 'desktop/electron-builder.config.cjs'));
assert(builderConfig.linux && typeof builderConfig.linux === 'object', 'electron-builder Linux configuration is an object');
assert(builderConfig.linux.desktop && typeof builderConfig.linux.desktop === 'object', 'Linux desktop configuration is present');
assert(builderConfig.linux.desktop.entry && typeof builderConfig.linux.desktop.entry === 'object', 'electron-builder v26 Linux desktop metadata uses desktop.entry');
assert(!Object.prototype.hasOwnProperty.call(builderConfig.linux.desktop, 'Name'), 'Linux desktop metadata is not placed at the obsolete flat desktop level');
assert(builderConfig.linux.executableName === 'rantlist', 'Linux executable name is explicit and matches the smoke-test path');
assert(builderConfig.win?.executableName === 'Rantlist', 'Windows executable name is explicit and matches installer expectations');
assert(builderConfig.win?.signExecutable === false, 'Windows code signing is disabled without disabling resource/icon editing');
assert(builderConfig.win?.signAndEditExecutable !== false, 'Windows resource/icon editing is not disabled');
const pkg = JSON.parse(read('desktop/package.json'));
assert(pkg.homepage === 'https://rantlist.me/', 'desktop package homepage is explicit for Linux package metadata');
assert(pkg.author && typeof pkg.author === 'object', 'desktop package author metadata is structured');
assert(pkg.author.name === 'Rantlist', 'desktop package author name is explicit');
assert(/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(pkg.author.email || '')), 'desktop package author email is present for DEB metadata');
assert(builderConfig.linux.maintainer === 'Rantlist <noreply@rantlist.me>', 'Linux maintainer is explicit for DEB packaging');
assert(builderConfig.deb?.maintainer === builderConfig.linux.maintainer, 'DEB maintainer matches Linux package maintainer');
assert(pkg.desktopName === 'fun.workwork.rantlist', 'Linux desktopName is explicit for launcher/window association');
const version = read('VERSION.txt').trim();
assert(pkg.version === version, 'desktop package version matches synchronized Rantlist source version');
assert(pkg.devDependencies?.electron === '44.5.1', 'Electron runtime is pinned');
assert(pkg.devDependencies?.['electron-builder'] === '26.15.3', 'electron-builder is pinned');
const win = read('scripts/build_windows_release.sh');
assert(win.includes('makensis'), 'Windows installer uses native Linux NSIS compiler');
assert(win.includes('--win --x64 --dir'), 'Windows packaging targets x64 without executing target binaries');
assert(win.includes('BUILD_NUMBER_OVERRIDE'), 'Windows remote release names include the shared release build number');
const linuxBuild = read('scripts/build_linux_release.sh');
assert(linuxBuild.includes('BUILD_NUMBER_OVERRIDE'), 'Linux remote release names include the shared release build number');
const workflow = read('scripts/release_and_deploy_homepage.sh');
assert(workflow.includes('macos android quest pico ios windows linux'), 'general release expands to all seven platforms including Quest and PICO');
assert(workflow.includes('build_desktop_remote.sh'), 'main release workflow delegates Windows/Linux builds to Ubuntu');
assert(workflow.includes('cleanup_desktop_remote_release.sh'), 'main release workflow cleans remote build artifacts only after completed release');
const publisher = read('scripts/publish_github_release.sh');
assert(publisher.includes('fetch_desktop_remote_artifacts.sh'), 'GitHub publisher automatically stages remote desktop artifacts');
assert(publisher.includes('windows-x64-Setup.exe') && publisher.includes('linux-x86_64.AppImage'), 'GitHub publisher includes Windows and Linux assets');
const homepage = read('scripts/deploy_homepage.sh');
assert(homepage.includes("kind=='windows'") && homepage.includes("kind=='linux_appimage'"), 'homepage resolves Windows and Linux release downloads');
console.log('Rantlist Windows/Linux desktop client verification passed.');
