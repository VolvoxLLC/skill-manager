# Build a native macOS Swift app for managing AI agent skills

I want to build a polished native macOS application in Swift for discovering, installing, updating, and managing AI agent skills across tools like Claude Code, Codex, GitHub Copilot, and other agent ecosystems.

The app should use Vercel’s Agent Skills Directory at https://www.skills.sh/ as the primary discovery source, and should also support installing skills from arbitrary GitHub repositories.

## Product concept

Create a native macOS app tentatively named **SkillDeck**.

SkillDeck helps developers keep their AI-agent skills up to date. Users should be able to:

- Browse/search skills from skills.sh
- Inspect skill metadata before installing
- Install skills into one or more supported agent directories
- Update installed skills when upstream versions change
- Add custom GitHub repositories that contain one or more skills
- Track which skills are installed, where they came from, and when they were last updated
- Enable/disable skills per agent ecosystem where applicable
- Schedule automatic update checks
- View logs and update history
- Resolve conflicts when local modifications exist

## Important clarification

Do not assume skills.sh has a stable public API without verifying it.

Start by researching how https://www.skills.sh/ exposes its data:
- Inspect the website
- Inspect network calls if needed
- Look for package/API endpoints
- Look at `npx skills add`
- Determine whether the app should use an HTTP API, scrape metadata, call a CLI, or integrate with GitHub repositories directly

Document the chosen integration approach and fallback strategy.

## Target platform

- Native macOS app
- Swift
- SwiftUI
- macOS 14+ or newer unless there is a strong reason to support older
- Use modern Apple frameworks and concurrency patterns
- Prefer Swift 6 / strict concurrency readiness where practical
- Xcode project should build cleanly

## UI requirements

The app should feel like a premium native macOS utility.

Requirements:
1. Use SwiftUI.
2. Respect the user’s macOS accent color.
3. Support light mode, dark mode, and system default.
4. Use native macOS design conventions.
5. Use a sidebar-based layout:
   - Discover
   - Installed
   - Sources
   - Updates
   - Logs
   - Settings
6. Include search, filtering, and sorting.
7. Use clear empty states.
8. Use native sheets/popovers for install/update confirmation.
9. Show progress for downloads, installs, and updates.
10. Include graceful error states.
11. Keyboard shortcuts should be included for common actions:
    - Search
    - Refresh
    - Install
    - Update all
    - Open settings
12. The app should feel fast and snappy.

## Core screens

### Discover

Users can search and browse skills from skills.sh.

Each skill row/card should show:
- Name
- Description
- Source repository or package
- Tags/categories if available
- Installs/activity if available
- Last updated if available
- Supported agent targets if detectable
- Install status

Skill detail view should show:
- README/SKILL.md preview
- Source URL
- Version/hash
- Install destinations
- Dependencies/requirements if present
- Install button
- Update button if already installed

### Installed

Shows locally installed skills.

Each installed skill should show:
- Name
- Installed version/hash
- Source
- Installed targets
- Last checked
- Last updated
- Local modification status
- Enable/disable state if supported
- Open in Finder
- Reveal source
- Check for updates
- Update
- Remove

### Sources

Users can add custom sources:
- GitHub repository URL
- Specific branch/tag

The app should scan custom repositories for skill files.

Support at least:
- `SKILL.md`
- `.claude/skills/...`
- `skills/...`
- repository structures used by skills.sh if discoverable

### Updates

Shows available updates across installed skills.

Actions:
- Update one
- Update selected
- Update all
- View diff before update
- Skip version
- Roll back if a previous version is available locally

### Logs

A user-facing log viewer for:
- Discovery syncs
- Installs
- Updates
- GitHub fetches
- File writes
- Errors
- Telemetry status

Logs should be searchable and filterable.

## Settings

The app needs a first-class Settings window using native macOS patterns.

Use SwiftUI `Settings` scenes and organize settings into clear sections/tabs.

Settings should be persisted locally and should apply immediately where possible.

### General

Include:

- Launch at login
- Show or hide menu bar item
- Default landing page:
  - Discover
  - Installed
  - Updates
  - Logs
- Enable background update checks
- Confirm before installing new skills
- Confirm before removing skills
- Confirm before overwriting local changes

### Installation behavior

Users should be able to choose how skills are installed.

Options:

1. **Copy files**
   - Default and safest option.
   - The app copies skill files into the selected agent skill directory.
   - Updates replace copied files only after conflict checks and backups.

2. **Symlink files**
   - Advanced option.
   - The app keeps a canonical managed copy in its application support directory and symlinks into agent skill directories.
   - Useful for sharing the same skill across multiple agents.
   - Must clearly warn users that deleting/moving the source can break installed skills.

Requirements:

- Allow global default install mode:
  - Copy
  - Symlink
- Allow per-agent override.
- Show the effective install mode during install preview.
- Never create symlinks outside approved skill directories.
- Validate symlink destinations to prevent path traversal.
- If symlink creation fails, offer fallback to file copy.
- Keep backups for both copied files and symlink targets when updating.

### Appearance

Include:

- Theme:
  - System
  - Light
  - Dark
- Respect macOS accent color by default.
- Optional app tint override:
  - System accent color
  - Blue
  - Green
  - Purple
  - Orange
  - Custom, if practical
- Text size:
  - Small
  - Default
  - Large
  - Extra Large
- Compact mode:
  - Off by default
  - Reduces row height and spacing for power users
- Skills Display:
  - Card
  - List
- Reduce motion:
  - Follow system setting by default
  - App override if practical

The UI should respond live to theme and text size changes.

### Language and localization

The app should be multilingual.

Requirements:

- Use Apple String Catalogs or `Localizable.strings`.
- Do not hard-code user-facing strings in views.
- Support language override inside the app:
  - System default
  - English
  - Spanish
  - French
  - German
  - Portuguese
  - Chinese
  - Japanese
  - Add more languages later
- If changing language requires restart, explain that clearly.
- Format dates, times, numbers, and relative update timestamps using the selected locale.
- Do not translate skill names, repository names, code paths, or agent names unless provided by the skill metadata.

Initial implementation can ship with English strings and architecture ready for additional languages, but the codebase must be localization-ready from the start.

### Updates

Include:

- Update check frequency:
  - Manual only
  - Every hour
  - Every 6 hours
  - Daily
  - Weekly
- Automatically update skills:
  - Off by default
  - Only trusted sources
  - All sources
- Auto-update safety policy:
  - Never auto-update skills with local modifications.
  - Never auto-update skills from unknown/untrusted custom sources unless user explicitly allows it.
  - Always create a backup before auto-update.
  - Log every auto-update.
- Update channel:
  - Stable
  - Include prerelease/beta skill versions, if the source supports version channels
- Notify when updates are available
- Notify when auto-update succeeds
- Notify when auto-update fails

### Agent targets

Include settings for supported agent ecosystems:

- Claude Code
- Codex
- GitHub Copilot
- Generic filesystem target

For each target:

- Enable/disable target
- Skill install path
- Detect default path
- Reset to default path
- Test write permissions
- Choose install mode:
  - Use global default
  - Copy
  - Symlink
- Open install folder in Finder
- Show target health:
  - Detected
  - Not detected
  - Missing path
  - No write permission
  - Unsupported version

### Sources

Include:

- Enable skills.sh source
- Refresh skills.sh index
- Clear skills.sh cache
- Add GitHub source
- Remove GitHub source
- Configure GitHub token, optional
- Respect GitHub rate limits
- Default branch preference:
  - Default repo branch
  - Specific branch
  - Specific tag/commit
- Trust level per source:
  - Trusted
  - Manual approval required
  - Disabled

### Conflict and backup behavior

Include:

- Default conflict resolution:
  - Always ask
  - Keep local changes
  - Overwrite after backup
- Backup retention:
  - Keep last 5 versions
  - Keep last 10 versions
  - Keep for 30 days
  - Keep forever
- Backup location
- Open backups folder
- Restore from backup
- Delete old backups

### Privacy and telemetry

Include:

- Enable/disable Sentry crash reporting
- Enable/disable Amplitude analytics
- Share anonymous usage analytics only
- Do not send skill contents
- Do not send private repository URLs
- Scrub local file paths from telemetry where possible
- View telemetry event log, if debug mode is enabled
- Reset anonymous analytics ID
- Open privacy notes

Defaults should be privacy-conscious:
- Sentry enabled only after clear disclosure or first-run consent.
- Amplitude disabled by default unless user opts in.
- Never send skill contents.

### Logging

Include:

- Log level:
  - Error
  - Warning
  - Info
  - Debug
- Export logs
- Clear logs
- Include debug logs in exported diagnostic bundle
- Log retention:
  - 7 days
  - 30 days
  - 90 days
  - Forever
- Show file paths in logs:
  - On by default locally
  - Always scrubbed from telemetry/export unless user opts in

### Notifications

Include:

- Update available notifications
- Auto-update success notifications
- Auto-update failure notifications
- Conflict requires attention notifications
- New trusted source detected notifications

Use native macOS notifications.

### Advanced

Include:

- Reset app database
- Clear all caches
- Rebuild skill index
- Re-scan installed skills
- Validate all installed skills
- Export settings
- Import settings
- Open Application Support folder
- Enable debug mode
- Enable experimental features

Advanced/destructive actions should require confirmation.

## Supported agent targets

Design the architecture so agent support is adapter-based.

Initial adapters:
1. Claude Code
2. Codex
3. GitHub Copilot
4. Generic filesystem target

Each adapter should define:
- Display name
- Default skill/instruction paths
- How to detect whether the agent is installed/configured
- How to install a skill
- How to remove a skill
- How to update a skill
- How to validate installed content
- Whether enable/disable is supported

Do not hard-code everything into UI views. Keep this extensible.

## Data model

Use a clean local persistence layer.

Preferred:
- SwiftData if suitable for the target macOS version
- SQLite via a small wrapper if SwiftData is not appropriate

Track:
- Skill
- SkillSource
- InstalledSkill
- AgentTarget
- UpdateCheck
- InstallOperation
- LogEntry
- UserSettings

Store enough metadata to compare local installed skills with upstream sources:
- Source URL
- Source type: skills.sh, GitHub repo, local path
- Version if available
- Commit SHA if GitHub-backed
- Content hash
- Installed file paths
- Last checked date
- Last installed date
- Last update result

Also persist user settings, including:

- appearanceMode
- accentColorMode
- textSize
- languageOverride
- showMenuBarItem
- launchAtLogin
- defaultInstallMode: copy or symlink
- perAgentInstallMode overrides
- enabledAgentTargets
- installPathsByAgent
- updateCheckFrequency
- autoUpdateEnabled
- autoUpdatePolicy
- trustedSources
- notificationPreferences
- telemetryPreferences
- logLevel
- logRetention
- backupRetention
- conflictResolutionDefault
- advanced/debug flags

## Skill installation behavior

Installation should be safe.

Requirements:
1. Never overwrite local changes without warning.
2. Before updating, compare current installed content against the last installed hash.
3. If local edits exist, show a conflict UI:
   - Keep local
   - Overwrite
   - View diff
   - Save backup then update
4. Keep backups of replaced skill files.
5. Validate skill structure before install.
6. Support dry-run/install preview.
   - The install preview must clearly show whether the app will copy files or create symlinks before the user confirms installation.
7. Use atomic file writes where possible.
8. Handle sandbox/security-scoped bookmarks if needed.

## GitHub source behavior

Users should be able to paste a GitHub repo URL and install skills from it.

Support:
- Public repos initially
- Branch selection if feasible
- Tag/commit pinning if feasible
- Subdirectory selection
- Update checks based on latest commit SHA
- GitHub archive download or GitHub API
- Graceful handling of rate limits

Avoid requiring Git to be installed if GitHub archive downloads are enough.

## skills.sh integration

Use skills.sh as the main discovery source.

Investigate and implement the best available approach:
- Public HTTP endpoint if available
- The data source used by the site if discoverable
- `npx skillsadd` behavior if needed
- GitHub source URLs exposed by skills.sh

The app should not depend on brittle scraping unless there is no better alternative. If scraping is unavoidable, isolate it behind a provider abstraction and document the risk.

## Networking

Use:
- URLSession
- async/await
- Codable
- structured error types
- cancellation support
- retry with backoff for transient failures

Do not block the main thread.

## Observability

### Sentry

Integrate Sentry for crash/error reporting.

Requirements:
- User can disable Sentry.
- Do not send skill content by default.
- Scrub file paths and personal data where possible.
- Add breadcrumbs for install/update operations.
- Capture non-fatal errors where useful.

### Amplitude

Integrate Amplitude for privacy-conscious product analytics.

Track events like:
- App launched
- Search performed
- Skill detail opened
- Skill installed
- Skill update checked
- Skill updated
- Custom source added
- Error occurred

Requirements:
- User can disable analytics.
- Do not send skill contents.
- Do not send private repository URLs unless user explicitly opts in.
- Use anonymous IDs by default.

## Logging

Build a comprehensive logging system.

Use Apple’s `Logger` / `OSLog` for system logs, plus an in-app log store for user-visible logs.

Log levels:
- Debug
- Info
- Warning
- Error

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

The in-app Logs screen should read from the app’s log store, not from private system logs.

## Testing

The project should be fully testable.

Include:
- Unit tests for data models
- Unit tests for skill parsing
- Unit tests for GitHub URL parsing
- Unit tests for skills.sh provider parsing
- Unit tests for update comparison/hash logic
- Unit tests for conflict detection
- Unit tests for agent adapters
- Mock network layer
- Mock file system layer
- Snapshot or UI tests for important views if practical

Avoid making business logic depend directly on SwiftUI views.

## Documentation

The project should be well documented.

Include:
- README.md
- Architecture overview
- Setup instructions
- How to run tests
- How to configure Sentry
- How to configure Amplitude
- Privacy notes
- Agent adapter design
- Adding a new agent target
- Adding a new skill source provider

Document public types and non-obvious logic with DocC-compatible comments.

## Architecture

Use a clean architecture with separation of concerns.

Suggested modules/layers:

- `App`
  - App entry point
  - Navigation
  - Settings injection

- `Core`
  - Models
  - Protocols
  - Errors
  - Logging
  - Hashing
  - Diffing

- `SkillSources`
  - skills.sh provider
  - GitHub provider
  - Local filesystem provider

- `AgentAdapters`
  - Claude adapter
  - Codex adapter
  - Copilot adapter
  - Generic adapter

- `Persistence`
  - Database models
  - Repositories

- `Services`
  - Skill installer
  - Update checker
  - Conflict detector
  - Backup manager

- `Telemetry`
  - Sentry wrapper
  - Amplitude wrapper
  - Privacy scrubber

- `UI`
  - SwiftUI views
  - View models
  - Reusable components

Use dependency injection so services can be mocked in tests.

## Performance requirements

- App launch should be quick.
- Discovery/search should not freeze the UI.
- Cache skills.sh results locally.
- Use incremental updates where possible.
- Use background tasks for update checks where appropriate.
- Avoid loading full skill contents for every row until needed.
- Use pagination/lazy loading if skills.sh has many entries.

## Security and privacy

Important:
- Never execute downloaded skill content.
- Treat all remote skill content as untrusted text.
- Do not automatically run shell commands from skills.
- Validate paths to prevent path traversal.
- Do not write outside configured install directories.
- Warn before overwriting files.
- Keep telemetry privacy-conscious.
- Support private data redaction in logs.

## Deliverables

Create a working Xcode project.

Include:
1. Native macOS SwiftUI app
2. Clean architecture
3. skills.sh discovery provider
4. GitHub repository source provider
5. Local installation/update management
6. Adapter-based agent target system
7. Sentry integration
8. Amplitude integration
9. In-app logging
10. Tests

11. Documentation

## Implementation plan

Work incrementally.

Phase 1:
- Create Xcode project
- App shell with sidebar navigation
- Models and protocols
- Local persistence
- Mock skill source
- Mock install flow
- Basic tests

Phase 2:
- Implement skills.sh discovery after researching actual integration
- Search and detail views
- Install preview

Phase 3:
- Implement GitHub repository sources
- Skill scanner
- Install/update logic
- Conflict detection and backups

Phase 4:
- Implement agent adapters
- Settings for install paths and enabled targets
- Update checks

Phase 5:
- Add Sentry, Amplitude, logging UI
- Polish UI
- Add documentation
- Add comprehensive tests

Phase 6:
- Final hardening
- Accessibility pass
- Performance pass
- CI setup if repository exists

## Quality bar

Do not produce a toy demo.

The app should be structured like a real macOS product:
- Native UI
- Strong architecture
- Testable services
- Clear error handling
- Safe file operations
- Privacy-conscious telemetry
- Good documentation
- Fast interaction
- Clean code

Before calling the task complete:
- Build the app
- Run all tests
- Fix warnings/errors
- Confirm the main flows work:
  - Browse/search skills
  - Add GitHub source
  - Preview install
  - Install skill
  - Detect update
  - Update skill
  - Handle local modification conflict
  - View logs
  - Change settings