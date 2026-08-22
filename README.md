# Rantlist Client

Public client-side source and native desktop packaging for **Rantlist**.

- Rantlist: https://rantlist.me
- Project page: https://mojoworks.xyz/labs/rantlist/
- Publisher: **WORKWORK.FUN**

`web/` is a sanitized snapshot of the browser-side client. The production server, database, deployment configuration, mail/TURN configuration, payment secrets and private infrastructure are not included.

## Synchronize the public client

```bash
./scripts/sync_from_stage.sh
```

The source defaults to `/Users/smielniczuk/Documents/works/stage/chat`. The Rantlist application version in that source is the only marketing-version authority for the client.

## Test macOS build

```bash
./scripts/update_and_build_macos.sh
```

This creates an ad-hoc local tester build.

## Full signed release + GitHub + homepage

```bash
./scripts/release_and_deploy_homepage.sh
```

No version argument is required. The workflow uses the current verified Rantlist version from `stage/chat`, allocates the next macOS build number, signs/notarizes the universal macOS app with the existing WORKWORK.FUN Apple credentials, pushes the public client source, creates the GitHub Release, uploads the DMG/ZIP/checksum files, and updates the Rantlist homepage at `https://mojoworks.xyz/labs/rantlist/` from the exact release tag.

The older entry point remains an alias to the same complete workflow:

```bash
./scripts/publish_macos_release.sh
```

Preflight only:

```bash
./scripts/release_and_deploy_homepage.sh --preflight-only
```

Resume after a network/GitHub/SSH failure by running the normal command again. See [RELEASE.md](RELEASE.md).

## Security model

The repository security scan rejects server/deployment files, payment/API token patterns, private keys, private IP addresses and explicit local service ports. Website SSH transport values are stored outside the repository in `~/.config/workwork/rantlist-release.env`; on the existing build Mac they are imported automatically from the local Cut release setup.
