#!/usr/bin/env node
/**
 * Puts a Sparkle <item> for a Clock In release at the top of the appcast, or prints it.
 *
 *   node scripts/update-appcast.js \
 *     --appcast updates/appcast.xml \
 *     --version 1.0.0 \
 *     --build 42 \
 *     --url https://github.com/LOUISINTERNET/timebutler-clockin-mac/releases/download/v1.0.0/ClockIn-1.0.0.dmg \
 *     --length 812345 \
 *     --signature "<edSignature from sign_update>" \
 *     --minimum-system-version 26.0 \
 *     --release-url https://github.com/LOUISINTERNET/timebutler-clockin-mac/releases/tag/v1.0.0 \
 *     [--item-only]
 *
 * --version is the tag without "v" (CFBundleShortVersionString), --build the workflow run
 * number (CFBundleVersion), which Sparkle compares. --item-only prints the item to stdout and
 * leaves the appcast alone: prereleases attach it to their GitHub release instead (FR-7).
 * The feed keeps the newest 20 items; older DMGs stay on the releases page. An item for the same
 * version is replaced, so a re-run of a release workflow leaves one item with the new signature.
 */

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const MAX_ITEMS = 20;
const VALUE_ARGUMENTS = ['appcast', 'version', 'build', 'url', 'length', 'signature', 'minimum-system-version', 'release-url'];
const FLAG_ARGUMENTS = ['item-only'];

function parseArguments(argv) {
  const values = {};
  const flags = new Set();
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    const name = argument.startsWith('--') ? argument.slice(2) : '';
    if (FLAG_ARGUMENTS.includes(name)) {
      flags.add(name);
    } else if (VALUE_ARGUMENTS.includes(name) && index + 1 < argv.length && !argv[index + 1].startsWith('--')) {
      values[name] = argv[index + 1];
      index += 1;
    } else if (VALUE_ARGUMENTS.includes(name)) {
      throw new Error(`Missing value for ${argument}`);
    } else {
      throw new Error(`Unknown argument: ${argument}. Expected --${[...VALUE_ARGUMENTS, ...FLAG_ARGUMENTS].join(', --')}`);
    }
  }
  for (const name of VALUE_ARGUMENTS) {
    if (values[name] === undefined || values[name].length === 0) {
      throw new Error(`Missing required argument: --${name}`);
    }
  }
  for (const name of ['build', 'length']) {
    if (!/^\d+$/.test(values[name])) {
      throw new Error(`--${name} must be a whole number, got: ${values[name]}`);
    }
  }
  return { values, itemOnly: flags.has('item-only') };
}

function escapeXml(raw) {
  return raw.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function buildItem(values) {
  const enclosure = [
    `url="${escapeXml(values.url)}"`,
    `sparkle:edSignature="${escapeXml(values.signature)}"`,
    `length="${values.length}"`,
    'type="application/octet-stream"',
  ].join(' ');
  return [
    '    <item>',
    `      <title>Version ${escapeXml(values.version)}</title>`,
    `      <link>${escapeXml(values['release-url'])}</link>`,
    `      <sparkle:version>${values.build}</sparkle:version>`,
    `      <sparkle:shortVersionString>${escapeXml(values.version)}</sparkle:shortVersionString>`,
    `      <sparkle:minimumSystemVersion>${escapeXml(values['minimum-system-version'])}</sparkle:minimumSystemVersion>`,
    `      <pubDate>${new Date().toUTCString()}</pubDate>`,
    `      <enclosure ${enclosure} />`,
    '    </item>',
  ].join('\n');
}

function shortVersionOf(item) {
  return item.match(/<sparkle:shortVersionString>(.*)<\/sparkle:shortVersionString>/)[1];
}

/** Rebuilds the channel as: metadata, the new item, the newest other versions, </channel>. */
function insertItem(xml, item, version, appcastPath) {
  const channelClose = xml.lastIndexOf('  </channel>');
  if (channelClose === -1) {
    throw new Error(`${appcastPath} has no "  </channel>" line; expected the layout of updates/appcast.xml`);
  }
  const channel = xml.slice(0, channelClose);
  const firstItem = channel.indexOf('    <item>');
  const metadata = firstItem === -1 ? channel : channel.slice(0, firstItem);
  const existing = channel.match(/ {4}<item>[\s\S]*?<\/item>\n/g) ?? [];
  const kept = existing.filter((existingItem) => shortVersionOf(existingItem) !== escapeXml(version)).slice(0, MAX_ITEMS - 1);
  return `${metadata}${item}\n${kept.join('')}${xml.slice(channelClose)}`;
}

function main() {
  const { values, itemOnly } = parseArguments(process.argv.slice(2));
  const item = buildItem(values);
  if (itemOnly) {
    process.stdout.write(`${item}\n`);
    return;
  }
  const appcastPath = values.appcast;
  const updated = insertItem(fs.readFileSync(appcastPath, 'utf8'), item, values.version, appcastPath);
  fs.writeFileSync(appcastPath, updated);
  const count = (updated.match(/<item>/g) ?? []).length;
  console.log(`${path.basename(appcastPath)}: added ${values.version} (build ${values.build}, ${values.length} bytes), ${count} items`);
}

main();
