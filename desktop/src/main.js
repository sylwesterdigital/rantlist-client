'use strict';

const { app, BrowserWindow, dialog, session, shell } = require('electron');
const path = require('path');

const DEFAULT_APP_URL = 'https://rantlist.me/';
const ALLOWED_HOSTS = new Set(['rantlist.me', 'www.rantlist.me']);
const SMOKE_TEST = process.argv.includes('--smoke-test');

function configuredAppUrl() {
  const raw = String(process.env.RANTLIST_APP_URL || DEFAULT_APP_URL).trim();
  let url;
  try { url = new URL(raw); } catch { throw new Error('RANTLIST_APP_URL must be a valid URL.'); }
  if (url.protocol !== 'https:' || !ALLOWED_HOSTS.has(url.hostname.toLowerCase())) {
    throw new Error('RANTLIST_APP_URL must use HTTPS on rantlist.me.');
  }
  return url.toString();
}

function isAllowedRantlistUrl(raw) {
  try {
    const url = new URL(String(raw || ''));
    return url.protocol === 'https:' && ALLOWED_HOSTS.has(url.hostname.toLowerCase());
  } catch { return false; }
}

function isSafeExternalUrl(raw) {
  try {
    const url = new URL(String(raw || ''));
    return ['https:', 'http:', 'mailto:'].includes(url.protocol);
  } catch { return false; }
}

async function openExternal(raw) {
  if (!isSafeExternalUrl(raw)) return;
  try { await shell.openExternal(raw, { activate: true }); } catch {}
}

function configurePermissions(ses) {
  const allowed = new Set(['media', 'notifications', 'fullscreen', 'pointerLock', 'clipboard-read']);
  ses.setPermissionCheckHandler((_contents, permission, requestingOrigin) => {
    return isAllowedRantlistUrl(requestingOrigin) && allowed.has(permission);
  });
  ses.setPermissionRequestHandler((webContents, permission, callback, details) => {
    const origin = details?.requestingUrl || webContents?.getURL?.() || '';
    callback(Boolean(isAllowedRantlistUrl(origin) && allowed.has(permission)));
  });
}

function installDownloadHandling(ses, parentWindow) {
  ses.on('will-download', (_event, item) => {
    const suggested = item.getFilename() || 'download';
    item.pause();
    dialog.showSaveDialog(parentWindow, {
      title: 'Save download',
      defaultPath: suggested,
      buttonLabel: 'Save'
    }).then(({ canceled, filePath }) => {
      if (canceled || !filePath) {
        item.cancel();
        return;
      }
      item.setSavePath(filePath);
      item.resume();
    }).catch(() => item.cancel());
  });
}

function createWindow() {
  const ses = session.fromPartition('persist:rantlist');
  configurePermissions(ses);

  const win = new BrowserWindow({
    width: 1380,
    height: 900,
    minWidth: 760,
    minHeight: 560,
    title: 'Rantlist',
    backgroundColor: '#070b10',
    icon: path.join(__dirname, '..', 'assets', 'icon.png'),
    show: false,
    webPreferences: {
      partition: 'persist:rantlist',
      nodeIntegration: false,
      nodeIntegrationInWorker: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      allowRunningInsecureContent: false,
      spellcheck: true,
      autoplayPolicy: 'document-user-activation-required'
    }
  });

  installDownloadHandling(ses, win);

  win.webContents.setWindowOpenHandler(({ url }) => {
    void openExternal(url);
    return { action: 'deny' };
  });

  win.webContents.on('will-navigate', (event, url) => {
    if (isAllowedRantlistUrl(url)) return;
    event.preventDefault();
    void openExternal(url);
  });

  win.webContents.on('render-process-gone', (_event, details) => {
    console.error(`Rantlist renderer exited: ${details.reason}`);
  });

  win.once('ready-to-show', () => win.show());
  win.loadURL(configuredAppUrl()).catch(async (error) => {
    console.error(error);
    await dialog.showMessageBox(win, {
      type: 'error',
      title: 'Rantlist',
      message: 'Rantlist could not connect.',
      detail: String(error?.message || error),
      buttons: ['Retry', 'Quit'],
      defaultId: 0,
      cancelId: 1
    }).then(({ response }) => {
      if (response === 0) win.loadURL(configuredAppUrl()).catch(() => {});
      else app.quit();
    });
  });

  return win;
}

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) app.quit();
else {
  let mainWindow = null;
  app.on('second-instance', () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
  });

  app.whenReady().then(() => {
    app.setName('Rantlist');
    if (SMOKE_TEST) {
      console.log(`Rantlist desktop smoke test OK (${process.platform}/${process.arch}, Electron ${process.versions.electron})`);
      app.quit();
      return;
    }
    mainWindow = createWindow();
    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) mainWindow = createWindow();
    });
  });

  app.on('window-all-closed', () => app.quit());
}
