#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const html = fs.readFileSync(path.join(__dirname, '../web/index.html'), 'utf8');
for (const id of ['serverInfoOnceTab', 'serverInfoMonthlyTab', 'serverInfoSupportChoices',
  'serverInfoSupportCheckoutLink', 'serverInfoAmountInput', 'serverInfoDonateRow',
  'serverInfoShareButton', 'serverInfoContributeLink', 'serverSupportOptionsInput']) {
  assert(html.includes(`id="${id}"`), `missing ${id}`);
}
for (const snippet of [
  'function normalizePublicSupportOptions(value)',
  'function renderServerSupportChoices(meta)',
  'function readSupportOptionsEditor()',
  'SUGGESTED_ONCE_AMOUNTS = [5, 10, 25, 50, 100, 250]',
  'checkout.href = selected.url',
  'button.textContent = choice.label',
  'Monthly donations are not set up yet',
  'Select and confirm your amount on Stripe',
  'elements.serverInfoAmountInput.addEventListener',
  'supportOptions,',
  "elements.serverInfoSupportChoices.setAttribute('aria-labelledby'",
]) assert(html.includes(snippet), `support flow missing: ${snippet}`);
for (const forbidden of ['<stripe-buy-button', 'serverInfoLegacyCheckout', 'serverInfoDonationLink', "label: 'General support'"]) {
  assert(!html.includes(forbidden), `obsolete confusing or duplicate UI remains: ${forbidden}`);
}
const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
  .filter((m) => !/\bsrc\s*=/.test(m[1]) && !/\btype\s*=\s*["'](?:importmap|application\/json|application\/ld\+json)/i.test(m[1]));
assert(scripts.length > 0);
for (const script of scripts) new vm.Script(script[2], {filename:'client-inline'});
console.log('PASS full client compact donation modal, fallback honesty, no duplicate CTA and valid inline JS');
