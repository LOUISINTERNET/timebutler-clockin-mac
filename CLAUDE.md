# Clock In

Native macOS 26 menu bar app for the Timebutler time clock. Swift 6 (strict concurrency), AppKit lifecycle, SwiftUI views, Liquid Glass, Swift Testing. No third-party dependencies.

## Commands

```bash
make build       # xcodegen generate + Debug build into build/
make run         # build and open the Debug app
make test        # unit tests, offline (skips LiveAPITests)
make test-live   # LiveAPITests against the real API; needs TIMEBUTLER_API_TOKEN (use read -s)
make install     # Debug build to /Applications
make release     # scripts/release.sh: archive, Developer ID export, notarize, DMG (needs keychain profile clockin-notary)
make clean
```

Always build the scheme `ClockIn`, never the test target directly. `make build` regenerates the Xcode project; after adding a Swift file, run `xcodegen generate` before a direct `xcodebuild` call.

## Architecture

```text
ClockIn/
  App/        AppDelegate (@main, custom main(), no nib), AppDependencies (composition root)
  API/        HTTPTransport (protocol + URLSessionTransport), TimebutlerAPI, APIError, TokenProvider, Models/
  Session/    SessionManager (actor, token refresh, keychain), OAuthClient, KeychainCredentialStore, SessionStateBroadcaster
  Clock/      ClockStore (@MainActor @Observable) + extensions (+Session, +Actions, +Errors), PollingScheduler, LiveClock, StopResult
  Widget/     WidgetPanel (non-activating NSPanel), WidgetPanelController, SwiftUI views, WidgetButton
  StatusBar/  StatusBarController (NSStatusItem), StatusBarMenu, StatusBarPresentation (pure)
  Settings/   SettingsWindowController, SettingsView, AccountTab, LoginFormModel/View, GeneralTab, AboutTab, LoginItemManager
  Support/    Log (os.Logger, subsystem app.clockin), Preferences (UserDefaults), DurationFormatting, AppIdentity
Tests/        Swift Testing, one file per type; Support/ has the fakes, Fixtures/ the JSON from the OpenAPI examples
```

Data flow: `PollingScheduler` → `ClockStore.refresh()` → `TimebutlerAPI` → `SessionManager.accessToken()`. Views read the store only. Errors are caught in `ClockStore` alone (`handle(_:during:)`); everything below throws.

Design decisions and requirements live in `specs/clock-in-mac-app/` (gitignored, local planning). The Timebutler OpenAPI spec is at `specs/clock-in-mac-app/docs/timebutler-openapi-v2.json`.

## Conventions

- Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY: complete`. UI types are `@MainActor`, models `Sendable`.
- No `try?`, `try!`, force unwraps or `fatalError` outside tests. Preconditions for programmer errors, thrown errors for everything else.
- Files stay around 200 lines; split with extensions (`ClockStore+Actions.swift`).
- UI texts German, identifiers, comments and commits English. Message strings come from `requirements.md` (FR-C8, FR-C11) and are asserted in tests verbatim.
- Logging: `Log.logger(.category)`, every interpolation with `privacy:`. Tokens, passwords and codes are never interpolated. `.notice` for lifecycle events (`log show` does not persist `.info`).
- Tests: strict assertions, in-memory fakes (`FixtureTransport` with per-endpoint `routes`, `InMemoryCredentialStore`, `TestStore` harness), no mocking of own code. Names without the word "test".

## Concurrency model

- `SessionManager` is an actor. Concurrent callers share one in-flight refresh task; sign-in and sign-out cancel it, so a late refresh can neither resurrect credentials nor expire the new session. Waiters then get `CancellationError`, which `ClockStore.handle` ignores on purpose.
- `ClockStore.apply(_:)` runs each session state once; a second call for the state being applied joins its task. Every fetch checks `session == expected` and `statusVersion` before writing, so answers that were overtaken are dropped.
- `isBusy` belongs to clock actions (widget buttons), `isAuthenticating` to the account tab. Do not merge them (EC-9).
- `ClockStore.stopObserving()` ends the session stream; `stop(decision:)` is the clock stop that posts to the server. Keep the names apart.

## Gotchas

- Xcode 26 hangs at "Discovering version info for clang" unless `CCC_OVERRIDE_OPTIONS=x-v` is set; the Makefile exports it, direct `xcodebuild` calls need it inline.
- `NSHostingView.sizingOptions` needs `.intrinsicContentSize` in addition to `.preferredContentSize`, otherwise `fittingSize` is zero and the panel starts 0×0 off screen.
- The widget panel never becomes key. `Color.accentColor` resolves to grey in inactive windows and the built-in glass button styles render inactive, so `WidgetButton` draws its own capsule with explicit tints.
- The development Mac has "Reduce transparency" on; Liquid Glass renders opaque there. Judge the glass look on a Mac without that setting.
- `NSScreen.main` is the screen with the key window, not the built-in display. `screencapture -x a.png b.png` captures every display for visual checks.
- The status item may be collapsed into the menu bar overflow ("•••") by a menu bar manager; check the lifecycle log (`log show --predicate 'subsystem == "app.clockin"'`) when it seems missing.
- Do not re-sign the app in build phases; signing is handled by `project.yml` (Automatic in Debug, Developer ID manual in Release) and `scripts/release.sh`.
- `SMAppService.mainApp.status` is `.notFound` while the app runs from `build/`; launch at login only works from `/Applications`.
- Never set `kSecUseDataProtectionKeychain`: without a provisioning profile (NFR-1) there is no keychain access group and every `SecItemAdd` fails with -34018. The app uses the login keychain; `security find-generic-password -s app.clockin` shows the item.
