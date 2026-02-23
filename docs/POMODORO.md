# Pomodoro Timer - Design Exploration

Status: **exploration / not committed to**

## Idea

Add a Pomodoro timer to Scanline, reusing the full-screen overlay system. The overlay that makes calendar alerts unmissable could also make focus/break transitions unmissable.

- Orange overlay when a work session is about to start / is starting
- Blue overlay when it's break time
- Snooze-style "delay" buttons with shorter intervals (1m, 3m, 5m) to postpone a focus or rest period
- Configurable work and break durations in Settings

## How it maps to existing architecture

~80% of the infrastructure is reusable:

| Existing | Pomodoro reuse |
|----------|---------------|
| OverlayWindow + OverlayView | As-is - just pass different content and colors |
| Snooze queue + reschedule | Becomes "delay start" with shorter intervals |
| EventMonitor timer scheduling | Same precise single-shot timer, driven by Pomodoro state instead of calendar alarms |
| AppState queue mechanism | Same enqueue/dismiss/snooze pattern |
| SettingsView form | Swap calendar pickers for duration pickers |
| MenuBarView | Add start/pause/reset controls + phase indicator |

### New code needed

- **PomodoroState** - state machine: idle -> work -> break -> work -> ... -> long break. Tracks cycle count, current phase, elapsed time.
- **Overlay color theming** - conditional styling in OverlayView (orange for work, blue for break)
- **Menu bar controls** - start/pause/reset, current phase label, countdown display
- **Settings section** - work duration (default 25m), break duration (default 5m), long break duration (default 15m), long break after N cycles (default 4), auto-start toggles

### Rough effort

2-3 days given the reuse. Most time goes into the PomodoroState machine and menu bar controls.

## Open questions / considerations

### Is it worth building?

**For:**
- Cheap to add - the overlay infra is already there
- Natural extension: "Scanline owns your focus for meetings, now it owns your focus periods too"
- Full-screen "GET BACK TO WORK" overlay is genuinely differentiated from typical Pomodoro apps
- You'd use it yourself

**Against:**
- Extremely crowded space - dozens of polished free Pomodoro apps exist
- A full-screen overlay for Pomodoro is kind of aggressive - niche appeal
- Maintenance burden for a secondary feature
- Risk of scope creep (stats, sounds, integrations)

**Verdict:** worth building only if it scratches a personal itch. Probably not a driver for adoption on its own, but almost free given the shared infra. Frame as a secondary feature, not a selling point.

### UX questions (if we proceed)

- Should Pomodoro overlays be less aggressive than calendar ones? (e.g. auto-dismiss after 30s?)
- Should work/break transitions auto-start or require confirmation via overlay?
- How does Pomodoro interact with calendar overlays? (pause Pomodoro during meetings?)
- Menu bar icon: show Pomodoro countdown in the menu bar title? Or keep it in the dropdown only?
