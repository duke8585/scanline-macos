<p align="center">
  <img src="docs/app-icon.png" width="128" alt="Scanline">
</p>

<h1 align="center">Scanline</h1>

<p align="center"><em>never miss the signal</em></p>

<p align="center">
  Full-screen calendar overlays for macOS.<br>
  CRT-style notifications that cut through deep focus when it matters.
</p>

---

<p align="center">
  <a href="https://youtu.be/GSsjef31SE0">
    <img src="https://img.shields.io/badge/▶_Demo-CRT_overlay_in_action-black?style=for-the-badge" alt="Demo video">
  </a>
</p>

## Features

- **Full-screen overlay** - unmissable event alerts that cover all screens, above everything including full-screen apps
- **Snooze & dismiss** - snooze for 1 or 5 minutes, or dismiss instantly
- **Menu bar app** - lives quietly in your menu bar, no dock icon
- **Multi-calendar support** - pick which calendars to monitor (any calendar synced to macOS Calendar - Google, iCloud, Exchange, etc.)
- **Smart alarm detection** - triggers on both explicit alarms and event start times
- **Zero dependencies** - native Swift + SwiftUI + AppKit, macOS 14.0+

## Install

### Homebrew

```
brew install duke8585/scanline/scanline
```

### Manual

Download the latest `.zip` from [Releases](https://github.com/duke8585/scanline-macos/releases), unzip, and move `Scanline.app` to `/Applications`.

### Build from source

```
make build
make run
```

Requires macOS 14.0+ and Xcode Command Line Tools. No Xcode project needed - builds with `swiftc` directly.

## How it works

Scanline monitors your system calendars via EventKit and throws a full-screen CRT-style overlay across every display when an event alarm fires - on top of everything, including full-screen apps. The overlay fades in with a retro CRT scanline animation, shows the event details, and lets you dismiss or snooze before diving back in.

On first launch, grant calendar access when prompted. Open Settings from the menu bar to pick which calendars to monitor.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
