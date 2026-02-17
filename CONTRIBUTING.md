# Contributing to Scanline

## Setup

```
git clone https://github.com/duke8585/scanline-macos.git
cd scanline-macos
make build
make run
```

Requires macOS 14.0+ and Xcode Command Line Tools.

## Development

```
make build       # compile .app bundle
make run         # build + open
make run-clean   # build + open with fresh UserDefaults
make clean       # remove build/
```

Builds with `swiftc` directly - no Xcode project needed. If you prefer Xcode, run `make generate` (requires [xcodegen](https://github.com/yonaskolb/XcodeGen)).

## Project structure

All source files live in `Sources/`. See [DESIGN.md](docs/DESIGN.md) for architecture and file-by-file breakdown.

## Pull requests

- Keep changes focused - one feature or fix per PR
- Test manually on macOS 14+ before submitting
- Match the existing code style (no linters enforced, just be consistent)
