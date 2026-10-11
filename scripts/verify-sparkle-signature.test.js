'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const SCRIPT = path.join(__dirname, 'verify-sparkle-signature.js');

function exampleKeyPair() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  const rawPublicKey = publicKey.export({ format: 'der', type: 'spki' }).subarray(-32);
  return { publicKey: rawPublicKey.toString('base64'), privateKey };
}

function exampleFile() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'signature-'));
  const file = path.join(directory, 'ClockIn-1.0.0.dmg');
  fs.writeFileSync(file, crypto.randomBytes(4096));
  return file;
}

function sign(file, privateKey) {
  return crypto.sign(null, fs.readFileSync(file), privateKey).toString('base64');
}

function run(file, publicKey, signature) {
  return spawnSync(process.execPath, [SCRIPT, '--file', file, '--public-key', publicKey, '--signature', signature], { encoding: 'utf8' });
}

test('a signature made with the matching private key passes', () => {
  const keys = exampleKeyPair();
  const file = exampleFile();
  const result = run(file, keys.publicKey, sign(file, keys.privateKey));
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, `EdDSA signature of ${file} matches SUPublicEDKey ${keys.publicKey}\n`);
});

test('a signature made with another private key fails', () => {
  const appKeys = exampleKeyPair();
  const otherKeys = exampleKeyPair();
  const file = exampleFile();
  const result = run(file, appKeys.publicKey, sign(file, otherKeys.privateKey));
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /EdDSA signature of .*ClockIn-1\.0\.0\.dmg does not match SUPublicEDKey/);
});

test('a changed file fails', () => {
  const keys = exampleKeyPair();
  const file = exampleFile();
  const signature = sign(file, keys.privateKey);
  fs.appendFileSync(file, 'x');
  const result = run(file, keys.publicKey, signature);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /does not match SUPublicEDKey/);
});

test('a public key that is not 32 bytes is rejected', () => {
  const keys = exampleKeyPair();
  const file = exampleFile();
  const result = run(file, 'c2hvcnQ=', sign(file, keys.privateKey));
  assert.equal(result.status, 1);
  assert.match(result.stderr, /SUPublicEDKey must be 32 bytes in base64, got 5 bytes/);
});
