#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const root = path.resolve(process.argv[2] || 'web');
const indexPath = path.join(root, 'index.html');
if (!fs.existsSync(indexPath)) {
  console.error(`Missing ${indexPath}`);
  process.exit(1);
}

let text = fs.readFileSync(indexPath, 'utf8');
const replacements = [
  // Public Stripe identifiers are not secrets in Stripe's model, but the public
  // client repository intentionally contains no live/test keys or reusable
  // payment identifiers at all. Production values remain server/runtime-owned.
  [/pk_live_[A-Za-z0-9]+/g, '__RANTLIST_STRIPE_PUBLISHABLE_KEY__'],
  [/pk_test_[A-Za-z0-9]+/g, '__RANTLIST_STRIPE_PUBLISHABLE_KEY__'],
  [/buy_btn_[A-Za-z0-9]+/g, '__RANTLIST_STRIPE_BUY_BUTTON_ID__'],
  [/https:\/\/buy\.stripe\.com\/[A-Za-z0-9]+/g, '__RANTLIST_SUPPORT_URL__'],
];

for (const [pattern, replacement] of replacements) {
  text = text.replace(pattern, replacement);
}

// The public browser-core snapshot is source/reference material. The packaged
// macOS client opens the hardened production HTTPS origin directly so the app
// does not need server ports, private API base URLs, TURN credentials or keys.
const marker = '<meta name="rantlist-public-client-snapshot" content="sanitized">';
if (!text.includes(marker)) {
  text = text.replace('</head>', `  ${marker}\n</head>`);
}

fs.writeFileSync(indexPath, text, 'utf8');
console.log(`Sanitized ${indexPath}`);
