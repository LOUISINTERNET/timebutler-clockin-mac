# Clock In

A native macOS menu bar app for the [Timebutler](https://app.timebutler.com) time clock: start, pause, resume and stop your working time from a floating widget, and keep the running time in the menu bar.

![The Clock In widget before signing in](docs/widget-signed-out.png)

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [Updates](#updates)
- [Build from source](#build-from-source)
- [Release](#release)
- [Security](#security)
- [Disclaimer](#disclaimer)
- [License](#license)

## Background

Timebutler's time clock lives in the browser. Clock In puts it on the desktop as a small always-visible widget with a live counter, plus a menu bar item that shows the net working time of the current session. It talks to the Timebutler REST API v2 and stores credentials in the macOS keychain only.

Clock In replaces an earlier internal solution built on an Übersicht widget and a shell script. Feature parity with that widget was the scope of version 1.

## Install

Requirements: macOS 26 (Tahoe) or newer, a Timebutler account with time tracking enabled.

1. Download the latest `ClockIn-<version>.dmg` from the [releases page](https://github.com/LOUISINTERNET/timebutler-clockin-mac/releases/latest).
2. Open the disk image and drag **Clock In** to **Applications**.
3. Start Clock In. It has no Dock icon; look for the clock symbol in the menu bar and the widget in the top right corner of the screen.

The app is signed with a Developer ID and notarized, so Gatekeeper opens it without a warning.

## Usage

### Sign in

Right-click the menu bar item, choose **Einstellungen…**, then either

- paste a **personal API token** (create one in Timebutler under *Einstellungen › Dein Konto › API-Token*, or open <https://app.timebutler.com/do?ha=personaltoken&ac=6>), or
- sign in with **e-mail and password**; accounts with two-factor authentication are asked for the six-digit authenticator code.

Personal tokens are the recommended way: they do not expire every few days and can be revoked individually in Timebutler.

### Widget

The widget shows the clock state (Gestoppt, Arbeit, Pause, Wartet), the running time, today's target, actual and remaining time, and the buttons the current state allows. The chevron in its header folds it to a single line with just the running time, like a collapsed sticky note. Drag it anywhere; its position and folded state survive a restart. It always opens toward the middle of the screen: placed in the right half it grows to the left, placed in the lower half it grows upward. When you stop a session that violates a break regulation, the widget shows Timebutler's proposal and lets you apply the correction, ignore it, or cancel the session.

### Menu bar

- Left click brings the widget to the front, and shows it if it was hidden.
- Right click opens the menu: show or hide the widget, refresh now, check for updates, settings (⌘,), quit (⌘Q).

### Settings

- **Konto**: who is signed in, and sign out.
- **Allgemein**: launch at login, show the widget, keep it above every other window or let windows cover it, show it on all Spaces, reset its position.
- **Info**: version, the update check, and the link to the Timebutler API documentation.

## Updates

Clock In updates itself with [Sparkle](https://sparkle-project.org). It checks in the background once a day; at launch only when the last check is more than a day old. An update found right after launch opens Sparkle's dialog. Later finds stay quiet: the menu entry changes to **Update auf <Version> installieren…** and waits for a click. **Nach Updates suchen…** in the right-click menu or under *Einstellungen › Info* checks at once.

Sparkle installs an update only if its EdDSA signature matches the public key in the app and the app keeps the same Developer ID signature. Versions before 1.0.0 have no updater; install 1.0.0 once by hand from the releases page.

## Build from source

Requirements: Xcode 26 and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
git clone git@github.com:LOUISINTERNET/timebutler-clockin-mac.git
cd timebutler-clockin-mac
make build
```

Useful targets (`make help` lists them all):

```bash
make run        # build and launch the Debug app
make test       # unit tests, offline with fixtures
make test-live  # read-only calls against the real API, needs TIMEBUTLER_API_TOKEN
make install    # copy the Debug build to /Applications
```

For the live test, keep the token out of your shell history:

```bash
read -s TIMEBUTLER_API_TOKEN && export TIMEBUTLER_API_TOKEN && make test-live
```

## Release

Releases are built by GitHub Actions only (`.github/workflows/release.yml`), triggered by a version tag on `main`:

```bash
git switch main && git pull --rebase && git tag v1.0.1 && git push origin main v1.0.1
```

The workflow refuses tags that are not on `main`. It runs the script and unit tests, archives a Release build with the tag as version and the run number as build number, signs it with the Developer ID, notarizes app and disk image, and signs the disk image for Sparkle, checking that signature against `SUPublicEDKey` of the built app. It then publishes the GitHub release `ClockIn-<version>.dmg` with generated release notes, which you can edit on GitHub afterwards. Finally it puts the new version at the top of `updates/appcast.xml` and commits that to `main`, so installed copies offer the update within a day. Run `git pull --rebase` after every release, otherwise your next push collides with that commit.

Tags with `-rc.N`, `-beta.N` or `-alpha.N` become GitHub prereleases. They leave the appcast alone and attach the finished `appcast-item.xml` instead; copy it into `updates/appcast.xml` by hand to test the update path. Only repository admins can create, move or delete `v*` tags (ruleset "Release tags").

### One-time setup

The secrets live in the environment `release`, which only `v*` tags may deploy to. Each `gh secret set` call prompts for the value:

```bash
R=LOUISINTERNET/timebutler-clockin-mac && gh secret set APPLE_ID --env release -R $R && gh secret set APPLE_APP_PASSWORD --env release -R $R && gh secret set APPLE_TEAM_ID --env release -R $R && gh secret set APPLE_CERT_PASSWORD --env release -R $R && gh secret set SPARKLE_PRIVATE_KEY --env release -R $R
base64 -i <developer-id.p12> | gh secret set APPLE_CERT_APP_P12_BASE64 --env release -R LOUISINTERNET/timebutler-clockin-mac
```

| Secret | Content |
|--------|---------|
| `APPLE_ID` | Apple ID of the Developer Program membership |
| `APPLE_APP_PASSWORD` | App-specific password of that Apple ID, from account.apple.com |
| `APPLE_TEAM_ID` | `A5278RL7RX` |
| `APPLE_CERT_APP_P12_BASE64` | The Developer ID Application certificate (G2) with its private key as `.p12`, base64-encoded; only this one certificate |
| `APPLE_CERT_PASSWORD` | Export password of that `.p12` |
| `SPARKLE_PRIVATE_KEY` | Private EdDSA key of the Sparkle account `app.clockin` |

The Sparkle key pair comes from Sparkle's `generate_keys --account app.clockin`; without `--account` the tool returns the key of another app. The public half is `SUPublicEDKey` in `ClockIn/Resources/Info.plist`, the private half is exported once with `generate_keys --account app.clockin -x <file>`. The workflow stops before building when a secret is missing, `SUPublicEDKey` is empty or `SUFeedURL` is not the appcast on `main`.

## Security

Credentials are stored in the macOS login keychain (service `app.clockin`) and are sent to `app.timebutler.com` only. Tokens, passwords and authenticator codes never appear in logs. The app is not sandboxed; it needs no entitlements beyond the hardened runtime.

## Disclaimer

Unofficial, not affiliated with Timebutler GmbH. Timebutler is a product of Timebutler GmbH.

## License

No license has been chosen yet. Until one is added, the code is proprietary to LOUIS INTERNET.
