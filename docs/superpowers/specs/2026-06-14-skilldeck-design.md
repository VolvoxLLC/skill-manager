# SkillDeck Design

## Summary

SkillDeck is a native macOS SwiftUI application for discovering, installing, updating, and managing AI-agent skills across Claude Code, Codex, GitHub Copilot, and generic filesystem targets.

The first implementation is a real MVP, not the entire long-form product wishlist. It will ship the core manager end to end: discovery/search, public GitHub source scanning, install preview, safe copy-based installs and updates, global and project-level destinations, conflict detection, backups, logs, settings, and opt-in Sentry/Amplitude wiring.

Full-spec items such as symlink install mode, private GitHub repositories, authenticated skills.sh API usage, advanced localization packs, menu bar workflows, and richer rollback history are designed as future extensions.

## Decisions

- Platform: native macOS app, SwiftUI, macOS 14+.
- Project shape: Xcode project with Swift packages for external SDKs where useful.
- Persistence: SwiftData with repository wrappers.
- Distribution posture: Mac App Store-ready sandbox model.
- Main layout: Finder-style sidebar, list, and inspector.
- Initial install mode: copy only.
- Install scopes: both global/user-level skill folders and project-level skill folders.
- skills.sh integration: public search endpoint only for MVP.
- GitHub sources: public repositories only for MVP.
- Updates: manual checks plus auto-update for trusted sources.
- Trust default: newly added sources are trusted by default, with hard safety stops.
- Telemetry: Sentry and Amplitude SDKs wired now, inert until explicit opt-in consent.

## Architecture

The app will keep UI, persistence, network fetching, file operations, and telemetry behind clear boundaries.

### App

Owns the app entry point, scene setup, dependency container, top-level navigation, first-run flow, and Settings scene.

### Core

Contains value models, shared errors, hashing, path validation, diff summaries, redaction helpers, and small utility protocols.

Core types should be UI-agnostic and easy to unit test.

### SkillSources

Defines `SkillSourceProviding` and source-specific implementations:

- `SkillsShSearchProvider`
- `GitHubSkillSourceProvider`
- `LocalSkillSourceProvider`

Providers return normalized skill summaries and skill details. They do not write to install destinations.

### AgentAdapters

Defines `AgentTargetAdapter` and initial adapters:

- Claude Code
- Codex
- GitHub Copilot
- Generic filesystem target

Each adapter defines display name, default install paths, detection behavior, validation behavior, and whether enable/disable is supported.

### Persistence

Uses SwiftData models plus repository wrappers so services and view models do not depend directly on SwiftData implementation details.

Persisted entities:

- `SkillRecord`
- `SkillSourceRecord`
- `InstalledSkillRecord`
- `AgentTargetRecord`
- `UpdateCheckRecord`
- `InstallOperationRecord`
- `LogEntryRecord`
- `UserSettingsRecord`
- `SecurityScopedFolderGrantRecord`
- `BackupRecord`

### Services

Owns workflows:

- Discovery sync
- GitHub source scan
- Install preview
- Installation
- Update check
- Auto-update
- Conflict detection
- Backup and restore
- Logging
- Notification scheduling

Services depend on protocols for network, filesystem, clock, hashing, persistence, telemetry, and notifications.

### Telemetry

Sentry and Amplitude are wrapped behind app-owned protocols. The wrappers must be no-ops until the user grants explicit consent.

No SwiftUI view should call Sentry or Amplitude directly.

## Discovery And Sources

The MVP uses skills.sh as a discovery index, not as install authority.

The official CLI currently uses:

```text
GET https://skills.sh/api/search?q=<query>&limit=<n>
```

This public endpoint returns skill IDs, skill names, install counts, and `owner/repo` sources. SkillDeck will use it for search and ranking.

The documented `/api/v1/*` endpoints require Vercel OIDC authentication. The MVP will not require Vercel authentication and will not ship a backend proxy.

Skill preview and install content come from public GitHub repository data:

- Resolve the source repo from the search result or user-provided GitHub URL.
- Fetch repository metadata and archive/tree contents through GitHub HTTP APIs.
- Scan for supported skill layouts.
- Read `SKILL.md` content as untrusted text.
- Derive content hash and source commit SHA.

Supported source layouts for MVP:

- Root `SKILL.md`
- `skills/<skill>/SKILL.md`
- `skills/<category>/<skill>/SKILL.md`
- `.claude/skills/<skill>/SKILL.md`
- `.agents/skills/<skill>/SKILL.md`

If skills.sh search is unavailable, the app should show a graceful degraded state and still allow users to add public GitHub sources directly.

Scraping skills.sh pages is not part of MVP. If a future version needs it, scraping must live behind a provider implementation with explicit risk documentation.

## Installation And Sandbox

The app is designed for App Store-ready sandboxing.

Users must grant each writable destination folder. SkillDeck stores security-scoped bookmarks for granted folders and revalidates access before writes.

Supported destination scopes:

- Global/user-level folders such as `~/.codex/skills`, `~/.claude/skills`, and `~/.copilot/skills`.
- Project-level folders such as `.agents/skills`, `.claude/skills`, and target-specific project paths inside user-selected repositories.
- Generic filesystem folders chosen by the user.

No folder grant means no write. Expired bookmark means no write until the user grants access again.

Path handling rules:

- Resolve and normalize every destination path before writing.
- Reject path traversal.
- Reject symlink escapes.
- Reject writes outside approved destination folders.
- Treat downloaded skill files as untrusted text.
- Never execute downloaded skill content.

MVP install mode is copy only. Symlink mode is deferred because sandbox-safe symlink behavior needs its own focused design.

## Install Preview

Every install or update goes through a preview step before user-triggered writes.

Preview shows:

- Skill name and source.
- Source commit/hash when available.
- Destination agents and folders.
- Install scope: global or project.
- Effective install mode: copy.
- Files to create or replace.
- Existing installed version/hash.
- Local modification status.
- Backup plan.
- Errors or missing permissions.

The preview must fail closed. If the app cannot validate the source, destination, hash, or folder grant, it should explain the problem and refuse the write.

## Conflict Detection And Backups

SkillDeck stores the content hash from the last successful install or update.

Before replacing an installed skill, the app computes the current installed hash:

- If it matches the last installed hash, the update can proceed after preview.
- If it differs, the app treats the skill as locally modified.

Conflict actions:

- Keep local changes.
- View diff summary.
- Back up then overwrite.

Every replacement creates a backup before the write. Backups are stored in the app support container with metadata that records source, destination, old hash, new hash, and timestamp.

MVP rollback is intentionally small: restore the latest backup from the Installed detail view. A full backup timeline can come later.

Writes should be atomic where practical:

- Stage files in app support or a temporary directory.
- Validate staged content.
- Create backup.
- Replace destination content.
- Verify final hash.
- Persist operation result.
- Log success or failure.

## Updates And Trust

The MVP supports manual update checks and auto-update for trusted sources.

Per product decision, newly added sources are trusted by default. That convenience does not bypass safety rules.

Auto-update must refuse to write when:

- The destination folder grant is missing or expired.
- Current installed files differ from the last installed hash.
- The source cannot resolve to a stable commit or content hash.
- The source fetch fails.
- Backup creation fails.
- The destination resolves outside the approved folder.
- The installed target has been disabled.

Every auto-update creates:

- Backup record.
- Install operation record.
- Log entry.
- User-visible update history.
- Notification if notifications are enabled.

Auto-update should be cancellable and should not block the main thread.

## User Interface

The main window uses a Finder-style layout:

- Sidebar: Discover, Installed, Sources, Updates, Logs, Settings.
- Middle pane: searchable, filterable, sortable list.
- Inspector pane: selected skill detail, README/SKILL.md preview, install/update actions, target status, conflicts, and source metadata.

Native sheets and popovers:

- Install preview.
- Update confirmation.
- Conflict resolution.
- Folder grant request.
- Source add/edit.
- First-run privacy consent.
- Destructive action confirmation.

Settings uses SwiftUI `Settings` scenes with sections:

- General
- Appearance
- Targets
- Sources
- Updates
- Privacy
- Logs
- Advanced

The UI must support light mode, dark mode, system appearance, macOS accent color, compact mode, and localization-ready strings from the start.

User-facing text should be centralized through String Catalogs or equivalent localization-ready resources. Skill names, repo names, agent names, and code paths are not translated unless source metadata explicitly provides localized values.

## Logging

Use Apple `Logger`/`OSLog` for system diagnostics and a SwiftData-backed in-app log store for user-visible logs.

Log categories:

- App
- Discovery
- Network
- GitHub
- Skills
- Install
- Update
- FileSystem
- Telemetry

In-app logs are searchable and filterable. Telemetry/export redaction must scrub local file paths unless the user explicitly opts into including them in diagnostics.

## Telemetry And Privacy

Sentry crash reporting and Amplitude analytics are wired through Swift Package Manager using their official Apple/Swift SDKs.

Telemetry defaults:

- Sentry off until explicit consent.
- Amplitude off until explicit consent.
- Consent prompts are separate.
- No skill contents are sent.
- No raw local file paths are sent.
- No private repository URLs are sent.
- Public source URLs are redacted or normalized where possible.

Tracked analytics events should be limited and product-relevant:

- App launched.
- Search performed.
- Skill detail opened.
- Skill installed.
- Update checked.
- Skill updated.
- Source added.
- Error occurred.

Telemetry wrappers must allow tests to assert that no outbound telemetry is attempted before consent.

## Error Handling

Errors should be structured and recoverable where possible.

Examples:

- `sourceUnavailable`
- `githubRateLimited`
- `invalidSkillStructure`
- `folderGrantMissing`
- `folderGrantExpired`
- `writePermissionDenied`
- `pathTraversalRejected`
- `localModificationDetected`
- `backupFailed`
- `hashMismatchAfterWrite`
- `telemetryConsentMissing`

User-facing errors should explain the next action, not expose raw stack traces.

## Testing

Tests should focus on the code that can hurt user files or silently corrupt state.

Unit tests:

- GitHub URL parsing.
- skills.sh search response parsing.
- Skill frontmatter parsing.
- Skill source scanning.
- Path safety.
- Hash comparison.
- Conflict detection.
- Backup rotation.
- Update decision logic.
- Agent adapters.
- Telemetry consent gating.

Service tests:

- Install preview with mock filesystem.
- Successful copy install.
- Missing folder grant.
- Local modification conflict.
- Backup failure.
- Update check with changed and unchanged sources.
- Auto-update refusal conditions.

Persistence tests:

- SwiftData repository save/load behavior.
- Installed skill update history.
- Log retention.
- Settings persistence.

UI verification:

- Main window empty states.
- Discover results.
- Installed detail.
- Install preview.
- Conflict sheet.
- Settings sections.

Before implementation is called complete, the app must build, tests must pass, and main flows must be manually verified.

## Documentation

Documentation deliverables:

- README setup and run instructions.
- Architecture overview.
- skills.sh integration notes and fallback strategy.
- Agent adapter guide.
- Adding a source provider.
- App Store sandbox/folder grant notes.
- Sentry configuration.
- Amplitude configuration.
- Privacy notes.
- Testing instructions.

## MVP Acceptance Criteria

The MVP is complete when a user can:

- Launch the macOS app.
- Grant target folders for global and project installs.
- Search skills from skills.sh.
- Add a public GitHub source.
- Inspect skill metadata and `SKILL.md` preview.
- Preview an install.
- Install a skill by copying files into approved destinations.
- See installed skills and their source/hash metadata.
- Detect an available update.
- Update a skill safely.
- Hit a local modification conflict and choose a safe outcome.
- Restore the latest backup.
- View searchable logs.
- Change key settings.
- Opt into or decline Sentry and Amplitude.
- Run tests successfully from the repo.

## Deferred Work

Deferred from MVP:

- Symlink install mode.
- Private GitHub repositories and token storage.
- Backend proxy for authenticated skills.sh `/api/v1/*` endpoints.
- Rich rollback timeline.
- Full localization translations.
- Menu bar item.
- Launch at login.
- Advanced telemetry event viewer.
- App Store submission metadata.
- CI setup, unless time allows after core implementation.

