'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');

const SCRIPT = path.join(__dirname, 'update-appcast.js');
const EMPTY_APPCAST = fs.readFileSync(path.join(__dirname, '..', 'updates', 'appcast.xml'), 'utf8');
const PUB_DATE_LINE = /^ {6}<pubDate>[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4} \d{2}:\d{2}:\d{2} GMT<\/pubDate>$/m;

function exampleArguments(overrides = {}) {
  const values = {
    version: '1.0.0',
    build: '42',
    url: 'https://github.com/LOUISINTERNET/timebutler-clockin-mac/releases/download/v1.0.0/ClockIn-1.0.0.dmg',
    length: '812345',
    signature: 'ZmFrZS1zaWduYXR1cmU=',
    'minimum-system-version': '26.0',
    'release-url': 'https://github.com/LOUISINTERNET/timebutler-clockin-mac/releases/tag/v1.0.0',
    ...overrides,
  };
  return Object.entries(values)
    .filter(([, value]) => value !== undefined)
    .flatMap(([name, value]) => [`--${name}`, value]);
}

function writeAppcast(content) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'appcast-'));
  const file = path.join(directory, 'appcast.xml');
  fs.writeFileSync(file, content);
  return file;
}

function run(appcast, extraArguments) {
  return spawnSync(process.execPath, [SCRIPT, '--appcast', appcast, ...extraArguments], { encoding: 'utf8' });
}

function items(xml) {
  return xml.match(/<item>[\s\S]*?<\/item>/g) ?? [];
}

function shortVersions(xml) {
  return items(xml).map((item) => item.match(/<sparkle:shortVersionString>(.*)<\/sparkle:shortVersionString>/)[1]);
}

function expectedItem(pubDateLine) {
  return [
    '    <item>',
    '      <title>Version 1.0.0</title>',
    '      <link>https://github.com/LOUISINTERNET/timebutler-clockin-mac/releases/tag/v1.0.0</link>',
    '      <sparkle:version>42</sparkle:version>',
    '      <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>',
    '      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>',
    pubDateLine,
    '      <enclosure url="https://github.com/LOUISINTERNET/timebutler-clockin-mac/releases/download/v1.0.0/ClockIn-1.0.0.dmg" sparkle:edSignature="ZmFrZS1zaWduYXR1cmU=" length="812345" type="application/octet-stream" />',
    '    </item>',
  ].join('\n');
}

function appcastWithVersions(versions) {
  let xml = EMPTY_APPCAST;
  for (const version of [...versions].reverse()) {
    const file = writeAppcast(xml);
    const result = run(file, exampleArguments({ version }));
    assert.equal(result.status, 0, result.stderr);
    xml = fs.readFileSync(file, 'utf8');
  }
  return xml;
}

test('an empty channel gets exactly the new item before </channel>', () => {
  const file = writeAppcast(EMPTY_APPCAST);
  const result = run(file, exampleArguments());
  assert.equal(result.status, 0, result.stderr);
  const xml = fs.readFileSync(file, 'utf8');
  const pubDateLine = xml.match(PUB_DATE_LINE)[0];
  const [head, tail] = EMPTY_APPCAST.split('  </channel>');
  assert.equal(xml, `${head}${expectedItem(pubDateLine)}\n  </channel>${tail}`);
  assert.equal(result.stdout, 'appcast.xml: added 1.0.0 (build 42, 812345 bytes), 1 items\n');
});

test('a new item goes before the existing ones', () => {
  const file = writeAppcast(appcastWithVersions(['1.0.0']));
  const result = run(file, exampleArguments({ version: '1.0.1', build: '43' }));
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(shortVersions(fs.readFileSync(file, 'utf8')), ['1.0.1', '1.0.0']);
});

test('the feed keeps the newest 20 items', () => {
  const twenty = Array.from({ length: 20 }, (_, index) => `1.0.${20 - index}`);
  const file = writeAppcast(appcastWithVersions(twenty));
  const result = run(file, exampleArguments({ version: '1.0.21' }));
  assert.equal(result.status, 0, result.stderr);
  const versions = shortVersions(fs.readFileSync(file, 'utf8'));
  assert.deepEqual(versions, ['1.0.21', ...twenty.slice(0, 19)]);
  assert.equal(versions.length, 20);
});

test('special characters are escaped', () => {
  const file = writeAppcast(EMPTY_APPCAST);
  const result = run(file, exampleArguments({ 'release-url': 'https://example.com/notes?a=1&b="2"' }));
  assert.equal(result.status, 0, result.stderr);
  const xml = fs.readFileSync(file, 'utf8');
  assert.match(xml, /^ {6}<link>https:\/\/example\.com\/notes\?a=1&amp;b=&quot;2&quot;<\/link>$/m);
});

test('a missing argument stops without touching the file', () => {
  const file = writeAppcast(EMPTY_APPCAST);
  const result = run(file, exampleArguments({ signature: undefined }));
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Missing required argument: --signature/);
  assert.equal(fs.readFileSync(file, 'utf8'), EMPTY_APPCAST);
});

test('--item-only prints the item and leaves the file alone', () => {
  const file = writeAppcast(EMPTY_APPCAST);
  const result = run(file, [...exampleArguments(), '--item-only']);
  assert.equal(result.status, 0, result.stderr);
  const pubDateLine = result.stdout.match(PUB_DATE_LINE)[0];
  assert.equal(result.stdout, `${expectedItem(pubDateLine)}\n`);
  assert.equal(fs.readFileSync(file, 'utf8'), EMPTY_APPCAST);
});

test('adding a version again replaces its item instead of listing it twice', () => {
  const file = writeAppcast(appcastWithVersions(['1.0.1', '1.0.0']));
  const result = run(file, exampleArguments({ version: '1.0.0', build: '99', signature: 'bmV1' }));
  assert.equal(result.status, 0, result.stderr);
  const xml = fs.readFileSync(file, 'utf8');
  assert.deepEqual(shortVersions(xml), ['1.0.0', '1.0.1']);
  assert.deepEqual(items(xml).map((item) => item.match(/<sparkle:version>(.*)<\/sparkle:version>/)[1]), ['99', '42']);
  assert.deepEqual(items(xml).map((item) => item.match(/sparkle:edSignature="([^"]*)"/)[1]), ['bmV1', 'ZmFrZS1zaWduYXR1cmU=']);
});
