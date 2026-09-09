# Clock In

A native macOS menu bar app for the [Timebutler](https://app.timebutler.com) time clock: start, pause, resume and stop your working time from a floating widget, and keep the running time in the menu bar.

![The Clock In widget before signing in](docs/widget-signed-out.png)

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
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

1. Download `ClockIn-<version>.dmg`.
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

The widget shows the clock state (Gestoppt, Läuft, Pause, Wartet), the running time, today's target, actual and remaining time, and the buttons the current state allows. Drag it anywhere; its position survives a restart. When you stop a session that violates a break regulation, the widget shows Timebutler's proposal and lets you apply the correction, ignore it, or cancel the session.

### Menu bar

- Left click brings the widget to the front, and shows it if it was hidden.
- Right click opens the menu: show or hide the widget, refresh now, settings (⌘,), quit (⌘Q).

### Settings

- **Konto**: who is signed in, and sign out.
- **Allgemein**: launch at login, show the widget, show it on all Spaces, reset its position.
- **Info**: version and the link to the Timebutler API documentation.

## Build from source

Requirements: Xcode 26, [xcodegen](https://github.com/yonaskolb/XcodeGen), and [create-dmg](https://github.com/create-dmg/create-dmg) for `make release`.

```bash
brew install xcodegen create-dmg
git clone <repository-url> clock-in
cd clock-in
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

`make release` archives a Release build, signs it with the Developer ID, notarizes app and disk image, staples both and writes `dist/ClockIn-<version>.dmg`. It needs a notarization profile in the keychain, created once per Mac:

```bash
xcrun notarytool store-credentials clockin-notary --apple-id <apple-id> --team-id A5278RL7RX --password <app-specific-password>
```

## Security

Credentials are stored in the macOS login keychain (service `app.clockin`) and are sent to `app.timebutler.com` only. Tokens, passwords and authenticator codes never appear in logs. The app is not sandboxed; it needs no entitlements beyond the hardened runtime.

## Disclaimer

Unofficial, not affiliated with Timebutler GmbH. Timebutler is a product of Timebutler GmbH.

## License

No license has been chosen yet. Until one is added, the code is proprietary to LOUIS INTERNET.
