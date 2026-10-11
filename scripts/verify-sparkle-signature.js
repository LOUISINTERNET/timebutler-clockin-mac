#!/usr/bin/env node
/**
 * Checks an EdDSA signature from Sparkle's sign_update against the app's SUPublicEDKey.
 *
 *   node scripts/verify-sparkle-signature.js \
 *     --file dist/ClockIn-1.0.0.dmg \
 *     --public-key "<SUPublicEDKey of the built app>" \
 *     --signature "<edSignature from sign_update>"
 *
 * sign_update signs with whatever key it is given. A SPARKLE_PRIVATE_KEY secret that belongs to
 * another app would pass the workflow and fail on every installed copy, so the workflow checks
 * the pair before it publishes anything.
 */

'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');

// DER prefix of an Ed25519 SubjectPublicKeyInfo; the 32 raw key bytes follow it.
const ED25519_SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');
const ARGUMENTS = ['file', 'public-key', 'signature'];

function parseArguments(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index].startsWith('--') ? argv[index].slice(2) : '';
    if (!ARGUMENTS.includes(name) || index + 1 >= argv.length) {
      throw new Error(`Unexpected argument ${argv[index]}. Usage: --file <path> --public-key <base64> --signature <base64>`);
    }
    values[name] = argv[index + 1];
  }
  for (const name of ARGUMENTS) {
    if (values[name] === undefined || values[name].length === 0) {
      throw new Error(`Missing required argument: --${name}`);
    }
  }
  return values;
}

function main() {
  const values = parseArguments(process.argv.slice(2));
  const rawPublicKey = Buffer.from(values['public-key'], 'base64');
  if (rawPublicKey.length !== 32) {
    console.error(`SUPublicEDKey must be 32 bytes in base64, got ${rawPublicKey.length} bytes`);
    process.exit(1);
  }
  const publicKey = crypto.createPublicKey({ key: Buffer.concat([ED25519_SPKI_PREFIX, rawPublicKey]), format: 'der', type: 'spki' });
  const matches = crypto.verify(null, fs.readFileSync(values.file), publicKey, Buffer.from(values.signature, 'base64'));
  if (!matches) {
    console.error(`EdDSA signature of ${values.file} does not match SUPublicEDKey ${values['public-key']}. SPARKLE_PRIVATE_KEY belongs to another key pair.`);
    process.exit(1);
  }
  console.log(`EdDSA signature of ${values.file} matches SUPublicEDKey ${values['public-key']}`);
}

main();
