# Security

This repository is intentionally client-only.

Do not commit production server code, SQLite data, `.env` files, private keys, TLS material, TURN credentials, mail credentials, Stripe secret/publishable integration keys, webhook secrets, GitHub tokens, SSH deployment credentials, internal/private IP addresses, or production deployment configuration.

Run before publishing:

```bash
./scripts/verify_client_repo.sh
node ./scripts/security_scan.js .
```

The macOS release uses Apple signing/notarization credentials already stored in macOS Keychain. The website deployment SSH host/port is kept in `~/.config/workwork/rantlist-release.env`, outside the public repository.
