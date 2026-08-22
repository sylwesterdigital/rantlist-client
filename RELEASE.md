# Rantlist macOS release workflow

The normal release command is:

```bash
./scripts/release_and_deploy_homepage.sh
```

It mirrors the verified Rantlist application version from `/Users/smielniczuk/Documents/works/stage/chat`; no release version is entered manually.

The workflow:

1. Preflights GitHub, Git transport, WORKWORK.FUN Developer ID, Apple notarization, SSH homepage deployment, source version metadata, required tools and disk space.
2. Synchronizes only the allow-listed/sanitized browser client into `web/`.
3. Plans the next macOS build number without writing it yet.
4. Builds a universal `arm64 + x86_64` Rantlist.app.
5. Signs with the existing WORKWORK.FUN Developer ID certificate and hardened runtime.
6. Notarizes and staples both app and DMG using the existing `workwork-caption-notary` Keychain profile.
7. Verifies Gatekeeper and SHA-256 assets.
8. Writes `BUILD_NUMBER.txt` only after the signed/notarized artifacts are complete.
9. Commits and pushes the public client source.
10. Creates an annotated tag `v<rantlist-version>-b<build>`.
11. Creates a draft GitHub release, uploads DMG/ZIP/SHA assets with retries, then publishes it.
12. Deploys `homepage/` from that exact pinned release tag to `https://mojoworks.xyz/labs/rantlist/` and verifies the public page.

## Resuming

The state file is `release/.release-workflow-state.env`.

If GitHub, SSH or the network fails after a build, run the same command again. Built artifacts and the planned build number are reused.

```bash
./scripts/release_and_deploy_homepage.sh
```

Inspect state:

```bash
./scripts/release_and_deploy_homepage.sh --status
```

Preflight without building/publishing:

```bash
./scripts/release_and_deploy_homepage.sh --preflight-only
```

Deliberately abandon an incomplete workflow:

```bash
./scripts/release_and_deploy_homepage.sh --restart
```

## Local website deployment profile

SSH host/port values are not committed to this public repository. On the existing WORKWORK.FUN Mac the script automatically imports the transport settings from the local Cut deployment script into:

```text
~/.config/workwork/rantlist-release.env
```

The Rantlist target is then derived as the sibling `/labs/rantlist` deployment. The local profile is mode `0600` and remains outside Git.

## Apple credentials

The workflow uses the same installed WORKWORK.FUN Developer ID certificate and Keychain notarization profile used by Cut. Credential secrets remain in macOS Keychain and are never copied into the repository or release artifacts.
