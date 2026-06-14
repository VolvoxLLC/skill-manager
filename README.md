# SkillDeck

SkillDeck is a native macOS app for discovering, installing, updating, and managing AI-agent skills across Claude Code, Codex, GitHub Copilot, and generic filesystem targets.

## Requirements

- macOS 14 or newer
- Xcode 26.3 or newer
- Swift 6.2 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

The Xcode project is generated from `project.yml` and is intentionally **not** committed. Run `xcodegen generate` before building the app, and again whenever you add or remove files under `SkillDeck/` or `SkillDeckTests/`.

## Project layout

- `Package.swift`, `Sources/`, `Tests/` — the `SkillDeckKit` Swift package holding all testable business logic (sources, agents, persistence, services, telemetry).
- `SkillDeck/` — the macOS SwiftUI app shell that consumes the package.
- `SkillDeckTests/` — app-hosted unit tests (view models).
- `project.yml` — XcodeGen spec used to generate `SkillDeck.xcodeproj`.

## Build

```bash
swift test
xcodegen generate
xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck \
  -destination 'platform=macOS' -derivedDataPath DerivedData build
```

## Test

```bash
# Package (business logic) tests — fast, no GUI needed:
swift test

# App-hosted tests (view models):
xcodegen generate
xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck \
  -destination 'platform=macOS' -derivedDataPath DerivedData test
```

A project-local `DerivedData/` path is used so builds are reproducible and easy to clean (`rm -rf DerivedData`).

## MVP scope

- Search skills.sh through the public `/api/search` endpoint.
- Scan public GitHub repositories for `SKILL.md`.
- Preview copy installs into user-approved folders.
- Detect local modifications with content hashes.
- Create backups before replacing files.
- Restore the latest backup.
- Show logs and key settings.
- Gate Sentry and Amplitude behind explicit user consent.

See [`docs/architecture.md`](docs/architecture.md) for the module breakdown, and
[`docs/integrations/`](docs/integrations) for skills.sh and telemetry notes.
