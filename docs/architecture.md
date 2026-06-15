# Architecture

SkillDeck separates SwiftUI views from business logic. All testable logic lives in
the `SkillDeckKit` Swift package (`Package.swift`); the macOS app target consumes the
package's products.

## Modules

- `SkillDeckCore`: domain models, errors, hashing, path safety, and `SKILL.md` parsing primitives. UI-agnostic and dependency-free.
- `SkillDeckSources`: skills.sh search, public GitHub scanning, and local source providers, all behind an injectable `HTTPClient`.
- `SkillDeckAgents`: adapter definitions for agent targets (Claude Code, Codex, GitHub Copilot).
- `SkillDeckPersistence`: SwiftData `@Model` records and a repository wrapper.
- `SkillDeckServices`: install preview, conflict detection, backups, copy install/restore, update checking, folder grants, and logging.
- `SkillDeckTelemetry`: consent-gated Sentry and Amplitude wrappers.
- `SkillDeck` (app): the macOS SwiftUI shell — dependency container, workflow view model, Finder-style window, sheets, and Settings.

## Testability

Services depend on protocols (`HTTPClient`, `FolderGrantChecking`, `GitHubRepositoryFetching`,
`SkillSearchProviding`, `TelemetrySink`) so tests can use temporary directories, mock HTTP
responses, in-memory folder grants, and recording telemetry sinks. No test writes to real
`~/.claude`, `~/.codex`, or `.agents` folders, and no test sends real telemetry.

`SkillDeckWorkspaceViewModel` composes the package services for the app surface. It owns the
current search results, scanned GitHub skills, selected detail, granted install folders, install
previews, installed skill state, available updates, conflict sheets, latest-backup restore, and
in-app log list. App-hosted tests cover the source-to-install and conflict-to-restore flows.

## Safety boundaries

- Every write destination is normalized and validated against an approved folder
  (`PathSafetyValidator`); traversal and escapes are rejected.
- Installs and updates fail closed when a folder grant is missing, a hash cannot be
  resolved, or a backup cannot be created.
- Downloaded `SKILL.md` content is treated as untrusted text and is never executed.
