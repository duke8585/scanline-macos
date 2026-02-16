# CalendarOverlay — Design Document

## 1. Problem

macOS calendar notifications are easy to miss — small banners that disappear. For people who rely on tight schedules, a missed notification means a missed meeting. There's no native way to make calendar alerts truly unmissable.

## 2. Solution

A lightweight macOS menu bar app that:
- Reads events from user-selected system calendars (via EventKit)
- Shows a **full-screen overlay** when an event's alarm fires — impossible to miss
- Provides dismiss and snooze controls (1 min, 5 min)
- Later: integrates a Pomodoro timer using the same overlay mechanism

## 3. User Experience

### 3.1 First Launch
1. App appears in menu bar (no dock icon)
2. macOS prompts for calendar access — user grants it
3. User opens menu bar dropdown → clicks Settings
4. Settings shows all system calendars grouped by account (Google, iCloud, etc.)
5. User toggles on the calendars they want to monitor
6. App is ready — no further configuration needed

### 3.2 Normal Operation
- App runs silently in the menu bar
- Polls selected calendars every ~15 seconds
- When an event's alarm time arrives → full-screen dark overlay appears
- Overlay shows: event title, time, calendar name/color
- User picks: **Dismiss**, **Snooze 1 min**, or **Snooze 5 min**
- Overlay disappears immediately on action
- Snoozed events re-trigger the overlay after the snooze period

### 3.3 Menu Bar Dropdown
- Shows next upcoming event (from selected calendars)
- "No calendars selected" hint if none are toggled
- Access to Settings
- Quit button

## 4. Technical Architecture

### 4.1 Stack
| Component | Choice | Rationale |
|-----------|--------|-----------|
| Language | Swift | Native macOS, best EventKit support |
| UI | SwiftUI | Modern, declarative, sufficient for this scope |
| Calendar | EventKit (EKEventStore) | System-level, works with any synced calendar provider |
| Menu bar | MenuBarExtra | Native SwiftUI API (macOS 13+) |
| Overlay | NSWindow (AppKit) | Required for window level control above all apps |
| Persistence | UserDefaults | Sufficient for calendar selection, no complex data |
| Project gen | xcodegen | Clean YAML → .xcodeproj, avoids manual Xcode config |
| Target | macOS 14.0+ | Enables @Observable macro, user is on 14.x |

### 4.2 Core Components

**CalendarOverlayApp** (entry point)
- `@main` SwiftUI App
- `LSUIElement = true` → no dock icon
- Hosts `MenuBarExtra` with SF Symbol icon
- Owns the `AppState` instance

**AppState** (shared state, `@Observable`)
- `selectedCalendarIDs: Set<String>` — persisted to UserDefaults
- `activeOverlayEvent: CalendarEvent?` — when non-nil, overlay shows
- `snoozeQueue: [(CalendarEvent, Date)]` — events + when to re-alert
- `permissionGranted: Bool`

**CalendarService** (EventKit wrapper)
- Requests full calendar access
- Lists all calendars with metadata (title, color, source/account name)
- Fetches events for a date range, filtered by selected calendars
- Computes alarm fire times: `event.startDate + alarm.relativeOffset`
  - Note: `relativeOffset` is negative (e.g., -300 = 5 min before)
  - Alarm fire time = `event.startDate.addingTimeInterval(alarm.relativeOffset)`

**EventMonitor** (alarm detection)
- `Timer` fires every 15 seconds
- Each tick:
  1. Fetch events from selected calendars for next 24 hours
  2. For each event, compute alarm fire times
  3. If alarm fire time is in the past and within the last 30 seconds → trigger
  4. Check snooze queue for expired snoozes → trigger
- Tracks fired alarms in `Set<String>` using `"\(event.eventIdentifier)_\(alarm.relativeOffset)"` to prevent duplicate alerts
- When triggered: sets `appState.activeOverlayEvent`

**OverlayWindow** (AppKit window controller)
- Creates borderless `NSWindow`
- Window level: `.screenSaver` (above everything, including full-screen apps)
- Style: `.borderless`, `.fullScreen`
- Covers all connected screens (one window per screen, or just primary — TBD)
- Background: semi-transparent dark (#000 at 85% opacity)
- Accepts mouse events for button interaction
- Hosts `OverlayView` via `NSHostingView`

**OverlayView** (SwiftUI)
- Centered card layout on dark backdrop
- Event title — large, SF Rounded, ~48pt, white
- Time range — "10:30 AM — 11:00 AM", lighter weight
- Calendar name with colored dot
- Three buttons in a row:
  - **Dismiss** (primary, larger)
  - **Snooze 1 min** (secondary)
  - **Snooze 5 min** (secondary)
- Simple, high contrast, no unnecessary decoration

**SettingsView** (SwiftUI)
- Opened from menu bar dropdown
- Lists calendars grouped by source (account)
- Each row: color dot, calendar name, toggle
- Changes persist immediately to UserDefaults
- None selected by default — user must opt in

### 4.3 Data Flow

```
EventKit (system calendars)
    │
    ▼
CalendarService ──fetches──▶ [EKEvent]
    │
    ▼
EventMonitor (15s timer)
    │ alarm due?
    ▼
AppState.activeOverlayEvent = event
    │
    ▼
OverlayWindow ──shows──▶ OverlayView
    │
    user action
    ├── Dismiss → activeOverlayEvent = nil
    ├── Snooze 1m → add to snoozeQueue, activeOverlayEvent = nil
    └── Snooze 5m → add to snoozeQueue, activeOverlayEvent = nil
```

## 5. File Structure

```
CalendarOverlay/
├── project.yml                        # xcodegen spec
├── Sources/
│   ├── CalendarOverlayApp.swift       # @main, MenuBarExtra
│   ├── AppState.swift                 # @Observable shared state
│   ├── CalendarService.swift          # EventKit wrapper
│   ├── EventMonitor.swift             # Polling + alarm detection
│   ├── OverlayWindow.swift            # NSWindow at screenSaver level
│   ├── OverlayView.swift              # Overlay SwiftUI view
│   ├── SettingsView.swift             # Calendar selection
│   └── MenuBarView.swift              # Menu bar dropdown
├── Resources/
│   └── Assets.xcassets/
└── CalendarOverlay.entitlements
```

## 6. Permissions & Entitlements

- **Calendar access**: `com.apple.security.personal-information.calendars` entitlement + runtime `EKEventStore.requestFullAccessToEvents()` prompt
- **No App Sandbox initially** — simplifies development. Can be sandboxed later for distribution.
- `LSUIElement = true` in Info.plist — hides dock icon

## 7. Edge Cases

| Scenario | Behavior |
|----------|----------|
| Calendar permission denied | Show "Calendar access needed" in menu bar dropdown with button to open System Settings |
| No calendars selected | Show "Select calendars in Settings" hint in dropdown |
| Multiple alarms on same event | Each alarm triggers independently |
| Multiple events alarm at same time | Queue them — show one at a time |
| Event deleted after alarm cached | Check event still exists before showing overlay |
| App launched after alarm time passed | Don't retroactively fire — only alarms whose time falls within a poll window |
| Snooze + original alarm overlap | Deduplicate by tracking fired combos |
| Screen locked | Overlay shows on unlock (window is already up) |

## 8. Future: Pomodoro Timer (deferred)

Same overlay mechanism, different trigger source:
- Menu bar shows Pomodoro controls (start, stop, reset)
- 25 min work → overlay "Time for a break!" with break duration options
- 5 min break → overlay "Back to work!" with start button
- Long break (15 min) after 4 cycles
- Reuses OverlayWindow and OverlayView with different content

## 9. Implementation Order

1. **Scaffolding** — project.yml, entitlements, directory structure, xcodegen
2. **App shell** — CalendarOverlayApp + MenuBarView (empty dropdown, menu bar icon)
3. **Calendar service** — EventKit access, list calendars, fetch events
4. **Settings** — calendar picker with persistence
5. **Event monitor** — polling, alarm detection
6. **Overlay** — NSWindow + OverlayView with dismiss/snooze
7. **Polish** — edge cases, multi-screen, queuing
