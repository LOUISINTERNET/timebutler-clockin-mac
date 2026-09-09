#!/usr/bin/env bash
# Builds, signs, notarizes and packages Clock In into dist/ClockIn-<version>.dmg (design decision D13).
# Prerequisite, once per Mac: xcrun notarytool store-credentials clockin-notary --apple-id <id> --team-id A5278RL7RX --password <app-specific-password>
set -euo pipefail

cd "$(dirname "$0")/.."

# Xcode 26 hangs at "Discovering version info for clang" without this (see Makefile).
export CCC_OVERRIDE_OPTIONS=x-v

profile="clockin-notary"
identity="Developer ID Application"
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
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "Clock In" -srcfolder "$staging" -format UDZO -ov "$dmg" >/dev/null
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
