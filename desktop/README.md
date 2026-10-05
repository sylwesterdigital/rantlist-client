# Rantlist desktop client

The Windows and Linux clients are a hardened Electron shell around the production HTTPS app at `https://rantlist.me/`. No Rantlist server process, private backend configuration, or local listening port is bundled.

The desktop shell keeps Node.js out of remote page content (`nodeIntegration: false`, `contextIsolation: true`, `sandbox: true`), allows top-level navigation only to the Rantlist HTTPS hosts, opens external HTTP(S)/mailto links in the operating-system browser, and grants browser permissions only to the Rantlist origin.

Builds are intentionally local to the checked-out client tree and `/srv/rantlist-build` cache/release directories. The release scripts never run `apt`, `sudo`, `systemctl`, Docker, package upgrades, service restarts, or cleanup outside their own build/cache directories.

On the prepared Ubuntu x86_64 build host run the scripts as the unprivileged `rantbuild` user:

```sh
./scripts/build_desktop_releases.sh
```

This produces separate Linux and Windows release ZIPs under `release/desktop/`.
