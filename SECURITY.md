## OpenAI BYOK credential storage

- **iOS:** the user-supplied OpenAI key is stored as a generic password in Apple Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- **macOS:** the user-supplied OpenAI key is stored in the user Keychain, not in WebView storage or repository/config files.
- **Android:** the key is encrypted with AES-GCM using an AES key generated inside `AndroidKeyStore`; only ciphertext and its IV are persisted. The WebView receives an origin-targeted `WebMessagePort`, avoiding an all-frame `addJavascriptInterface` secret getter.
- **Browser:** the key is memory-only. It is not written to `localStorage`, IndexedDB, cookies, or exported configuration and is forgotten on reload/close.
- Legacy `chat.ai.openai.apiKey` localStorage data is migrated once into native secure storage when available, then removed. In an ordinary browser it is loaded only into the current page memory and removed from persistent storage.
- The native bridge exposes a credential only to the trusted Rantlist main frame and only when an OpenAI request needs it. Diagnostics redact API-key-shaped fields and OpenAI key strings.

Encrypted SQLite is intentionally not the trust anchor: if an application bundles or can automatically retrieve a SQLite decryption key, an attacker with the same process/device access can usually retrieve it too. Platform credential stores provide the stronger OS-backed boundary.

# Security

This repository is intentionally client-only.

Do not commit production server code, SQLite data, `.env` files, private keys, TLS material, TURN credentials, mail credentials, Stripe secret/publishable integration keys, webhook secrets, GitHub tokens, SSH deployment credentials, internal/private IP addresses, or production deployment configuration.

Run before publishing:

```bash
./scripts/verify_client_repo.sh
node ./scripts/security_scan.js .
```

The macOS release uses Apple signing/notarization credentials already stored in macOS Keychain. The website deployment SSH host/port is kept in `~/.config/workwork/rantlist-release.env`, outside the public repository.
