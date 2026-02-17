# Scanline

macOS menu bar app that shows full-screen overlays for calendar events. See [DESIGN.md](docs/DESIGN.md) for full spec, UX, and architecture.

## Stack

Swift + SwiftUI + AppKit. macOS 14.0+. No dependencies.

- **EventKit** for calendar access (single shared `EKEventStore`)
- **MenuBarExtra** for menu bar UI (SwiftUI)
- **NSWindow** at `.screenSaver` level for overlay (AppKit)
- **@Observable** for state (`AppState` is the single source of truth)
- **UserDefaults** for persisting calendar selection
- **xcodegen** generates `.xcodeproj` from `project.yml`

## Build

```
make build   # compiles .app bundle via swiftc
make run     # build + open
make clean   # remove build/
```

No Xcode required - builds with `swiftc` directly. The `project.yml` + xcodegen exist for if/when Xcode is needed.

## Architecture

`AppDelegate` creates `AppState` at launch → `AppState.setup()` requests calendar permission and starts `EventMonitor`.

| File | Role |
|------|------|
| `CalendarOverlayApp.swift` | `@main`, `MenuBarExtra`, `AppDelegate` |
| `AppState.swift` | shared state, owns `CalendarService`, `EventMonitor`, `OverlayWindowController` |
| `CalendarService.swift` | EventKit wrapper - access, list calendars, fetch events |
| `EventMonitor.swift` | 15s poll timer, alarm detection (explicit alarms + event start time), snooze queue |
| `OverlayWindow.swift` | borderless NSWindow per screen, `.screenSaver` level |
| `OverlayView.swift` | SwiftUI overlay - title, time, calendar dot, dismiss/snooze buttons |
| `SettingsView.swift` | calendar picker grouped by source, test overlay button |
| `MenuBarView.swift` | dropdown - next event, sync now, settings, quit |

## Key patterns

- `AppState` is a class (`@Observable`), owned by `AppDelegate` - lives for the app lifetime, not recreated by SwiftUI
- overlay show/hide driven by `didSet` on `activeOverlayEvent`
- `OverlayWindowController.close()` uses `orderOut` (not `close()`) to avoid tearing down views mid-callback
- `EventMonitor` triggers on both explicit `EKAlarm` offsets and event start time (most events use calendar default alerts, not explicit alarms)
- detection window is 60s, poll interval 15s

## Release process

Releases are fully automated via GitHub Actions. Pushing a version tag triggers a build, creates a GitHub release, and updates the Homebrew cask.

### Repos

- **App**: [duke8585/scanline-macos](https://github.com/duke8585/scanline-macos)
- **Homebrew tap**: [duke8585/homebrew-scanline](https://github.com/duke8585/homebrew-scanline) - auto-updated by the release workflow

### How to release

Pick the right bump level and run the corresponding make target:

```
make tag-patch   # v0.5.0 -> v0.5.1 (bug fixes)
make tag-minor   # v0.5.0 -> v0.6.0 (new features)
make tag-major   # v0.5.0 -> v1.0.0 (breaking changes)
```

This creates and pushes a git tag, which triggers the [release workflow](.github/workflows/release.yml):

1. Runs tests (`make test`)
2. Builds a universal binary (arm64 + x86_64) via `make release`
3. Creates a GitHub Release with the zip attached
4. Clones `duke8585/homebrew-scanline`, updates version + sha256 in the cask, commits and pushes

Requires the `HOMEBREW_TAP_TOKEN` secret (fine-grained PAT scoped to the homebrew-scanline repo with contents read+write).
