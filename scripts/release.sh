#!/usr/bin/env bash
# Builds, signs, notarizes and packages Clock In into dist/ClockIn-<version>.dmg (design decision D13).
# Prerequisite, once per Mac: xcrun notarytool store-credentials clockin-notary --apple-id <id> --team-id A5278RL7RX --password <app-specific-password>
set -euo pipefail

cd "$(dirname "$0")/.."

# Xcode 26 hangs at "Discovering version info for clang" without this (see Makefile).
export CCC_OVERRIDE_OPTIONS=x-v

profile="clockin-notary"
# SHA-1 of the Developer ID Application certificate from the G2 CA (valid until 2031-09-17).
# The bare name is ambiguous while the old certificate (expires 2027-02-01) is in the keychain.
identity="DA4198799C8B6998BE4690BDADCB108F1AE397DB"
version="$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)"
archive="dist/ClockIn.xcarchive"
export_dir="dist/export"
app="$export_dir/ClockIn.app"
dmg="dist/ClockIn-$version.dmg"
staging="dist/dmg-root"

if [[ -z "$version" ]]; then
    echo "MARKETING_VERSION not found in project.yml" >&2
    exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg is missing. Install it once with: brew install create-dmg" >&2
    exit 1
fi

if ! xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1; then
    echo "Notarization profile '$profile' is missing. Create it once with:" >&2
    echo "  xcrun notarytool store-credentials $profile --apple-id <apple-id> --team-id A5278RL7RX --password <app-specific-password>" >&2
    exit 1
fi

echo "Releasing Clock In $version"
rm -rf dist
mkdir -p dist

xcodegen generate
xcodebuild -project ClockIn.xcodeproj -scheme ClockIn -configuration Release -destination "generic/platform=macOS" -archivePath "$archive" archive -quiet
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist installer/ExportOptions.plist -exportPath "$export_dir" -quiet

echo "Notarizing the app"
ditto -c -k --keepParent "$app" dist/ClockIn.zip
xcrun notarytool submit dist/ClockIn.zip --keychain-profile "$profile" --wait
xcrun stapler staple "$app"

echo "Building the disk image"
# create-dmg lays out the familiar drag-to-Applications window: 660x420, app on the left,
# Applications link on the right, arrow from installer/dmg-background.png.
mkdir -p "$staging"
cp -R "$app" "$staging/"
create-dmg \
    --volname "Clock In" \
    --background installer/dmg-background.png \
    --window-pos 200 120 \
    --window-size 660 420 \
    --icon-size 140 \
    --icon "ClockIn.app" 180 150 \
    --app-drop-link 480 150 \
    --hide-extension "ClockIn.app" \
    --no-internet-enable \
    "$dmg" \
    "$staging"
codesign --force --timestamp --sign "$identity" "$dmg"

echo "Notarizing the disk image"
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"

echo "Verifying"
xcrun stapler validate "$app"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"

rm -rf "$staging" dist/ClockIn.zip
echo "Release ready: $dmg"
