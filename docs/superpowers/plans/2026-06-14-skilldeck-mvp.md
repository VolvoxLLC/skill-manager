# SkillDeck MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first real SkillDeck MVP: a native macOS SwiftUI app that discovers skills, scans public GitHub sources, previews and copies installs into approved folders, checks updates, handles conflicts/backups, logs operations, and gates Sentry/Amplitude behind consent.

**Architecture:** Use a small Swift package for testable business logic and an Xcode macOS app target for the native SwiftUI shell. Keep network, filesystem, persistence, telemetry, and UI behind protocols so core workflows can be tested without touching user files or external services.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, URLSession, CryptoKit, OSLog, XCTest, Xcode 26.3, Sentry Apple SDK (`https://github.com/getsentry/sentry-cocoa.git`), Amplitude Swift SDK (`https://github.com/amplitude/Amplitude-Swift`).

---

## Scope Check

This plan implements one MVP slice from the approved design:

- Native macOS app shell with Finder-style navigation.
- Core domain models, provider protocols, and service protocols.
- Public skills.sh search through `https://skills.sh/api/search`.
- Public GitHub source scanning and `SKILL.md` parsing.
- Copy-only install preview and copy install.
- Security-scoped folder grant model and path-safety checks.
- Conflict detection, backups, latest-backup restore.
- Manual updates and trusted-source auto-update policy.
- SwiftData persistence.
- In-app logs.
- Consent-gated Sentry and Amplitude wrappers.
- README and architecture docs.

Deferred design items stay out of this plan: symlink mode, private GitHub auth, backend proxy, full translation packs, menu bar item, launch at login, full backup timeline, and App Store submission metadata.

## File Structure

Create or modify these files. If a deeper `AGENTS.md` appears during execution, read it before editing files under its directory.

```text
Package.swift
SkillDeck.xcodeproj/
SkillDeck/SkillDeckApp.swift
SkillDeck/App/DependencyContainer.swift
SkillDeck/App/SkillDeckCommands.swift
SkillDeck/Resources/Localizable.xcstrings
SkillDeck/SkillDeck.entitlements
SkillDeck/Views/MainWindowView.swift
SkillDeck/Views/DiscoverView.swift
SkillDeck/Views/InstalledView.swift
SkillDeck/Views/SourcesView.swift
SkillDeck/Views/UpdatesView.swift
SkillDeck/Views/LogsView.swift
SkillDeck/Views/SkillInspectorView.swift
SkillDeck/Views/InstallPreviewSheet.swift
SkillDeck/Views/ConflictResolutionSheet.swift
SkillDeck/Views/ConsentSheet.swift
SkillDeck/Settings/SkillDeckSettingsView.swift
SkillDeck/ViewModels/DiscoverViewModel.swift
SkillDeck/ViewModels/InstalledViewModel.swift
SkillDeck/ViewModels/SourcesViewModel.swift
SkillDeck/ViewModels/UpdatesViewModel.swift
SkillDeck/ViewModels/LogsViewModel.swift
Sources/SkillDeckCore/Models/SkillModels.swift
Sources/SkillDeckCore/Models/AgentModels.swift
Sources/SkillDeckCore/Models/SettingsModels.swift
Sources/SkillDeckCore/SkillDeckError.swift
Sources/SkillDeckCore/Hashing/ContentHasher.swift
Sources/SkillDeckCore/Paths/PathSafetyValidator.swift
Sources/SkillDeckCore/Parsing/SkillManifestParser.swift
Sources/SkillDeckSources/SkillSourceProviding.swift
Sources/SkillDeckSources/SkillsShSearchProvider.swift
Sources/SkillDeckSources/GitHubURLParser.swift
Sources/SkillDeckSources/GitHubRepositoryClient.swift
Sources/SkillDeckSources/GitHubSkillSourceProvider.swift
Sources/SkillDeckSources/LocalSkillSourceProvider.swift
Sources/SkillDeckAgents/AgentTargetAdapter.swift
Sources/SkillDeckAgents/DefaultAgentAdapters.swift
Sources/SkillDeckPersistence/SkillDeckSchema.swift
Sources/SkillDeckPersistence/SkillDeckRepository.swift
Sources/SkillDeckServices/Logging/AppLogService.swift
Sources/SkillDeckServices/Security/FolderGrantStore.swift
Sources/SkillDeckServices/Install/InstallPreviewService.swift
Sources/SkillDeckServices/Install/ConflictDetector.swift
Sources/SkillDeckServices/Install/BackupManager.swift
Sources/SkillDeckServices/Install/SkillInstaller.swift
Sources/SkillDeckServices/Update/UpdateChecker.swift
Sources/SkillDeckServices/Update/AutoUpdatePolicy.swift
Sources/SkillDeckTelemetry/TelemetryConsentStore.swift
Sources/SkillDeckTelemetry/TelemetryClient.swift
Sources/SkillDeckTelemetry/SentryTelemetryClient.swift
Sources/SkillDeckTelemetry/AmplitudeTelemetryClient.swift
Tests/SkillDeckCoreTests/
Tests/SkillDeckSourcesTests/
Tests/SkillDeckAgentsTests/
Tests/SkillDeckPersistenceTests/
Tests/SkillDeckServicesTests/
Tests/SkillDeckTelemetryTests/
docs/architecture.md
docs/integrations/skills-sh.md
docs/integrations/telemetry.md
README.md
```

## Implementation Rules

- Before each task: run `rtk proxy find . -name AGENTS.md -print` and read any new file found.
- Use TDD for non-UI logic: write failing test, run it, implement, run passing test, commit.
- Keep commits task-sized.
- Do not write to real `~/.codex`, `~/.claude`, or `.agents` folders in tests. Use temporary directories only.
- Do not send real Sentry or Amplitude events in tests.
- Use security-scoped bookmark code only from the app layer; service tests use mock grants.

---

### Task 1: Bootstrap Project And Package Boundaries

**Files:**
- Create: `Package.swift`
- Create: `SkillDeck.xcodeproj`
- Create: `SkillDeck/SkillDeckApp.swift`
- Create: `SkillDeck/Views/MainWindowView.swift`
- Create: `SkillDeck/Resources/Localizable.xcstrings`
- Create: `SkillDeck/SkillDeck.entitlements`
- Create: `Tests/SkillDeckCoreTests/BootstrapTests.swift`

- [ ] **Step 1: Create the Swift package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SkillDeck",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SkillDeckCore", targets: ["SkillDeckCore"]),
        .library(name: "SkillDeckSources", targets: ["SkillDeckSources"]),
        .library(name: "SkillDeckAgents", targets: ["SkillDeckAgents"]),
        .library(name: "SkillDeckPersistence", targets: ["SkillDeckPersistence"]),
        .library(name: "SkillDeckServices", targets: ["SkillDeckServices"]),
        .library(name: "SkillDeckTelemetry", targets: ["SkillDeckTelemetry"])
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "8.0.0"),
        .package(url: "https://github.com/amplitude/Amplitude-Swift", from: "1.0.0")
    ],
    targets: [
        .target(name: "SkillDeckCore"),
        .target(
            name: "SkillDeckSources",
            dependencies: ["SkillDeckCore"]
        ),
        .target(
            name: "SkillDeckAgents",
            dependencies: ["SkillDeckCore"]
        ),
        .target(
            name: "SkillDeckPersistence",
            dependencies: ["SkillDeckCore"]
        ),
        .target(
            name: "SkillDeckServices",
            dependencies: [
                "SkillDeckCore",
                "SkillDeckSources",
                "SkillDeckAgents",
                "SkillDeckPersistence"
            ]
        ),
        .target(
            name: "SkillDeckTelemetry",
            dependencies: [
                "SkillDeckCore",
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "AmplitudeSwift", package: "Amplitude-Swift")
            ]
        ),
        .testTarget(
            name: "SkillDeckCoreTests",
            dependencies: ["SkillDeckCore"]
        ),
        .testTarget(
            name: "SkillDeckSourcesTests",
            dependencies: ["SkillDeckSources"]
        ),
        .testTarget(
            name: "SkillDeckAgentsTests",
            dependencies: ["SkillDeckAgents"]
        ),
        .testTarget(
            name: "SkillDeckPersistenceTests",
            dependencies: ["SkillDeckPersistence"]
        ),
        .testTarget(
            name: "SkillDeckServicesTests",
            dependencies: ["SkillDeckServices"]
        ),
        .testTarget(
            name: "SkillDeckTelemetryTests",
            dependencies: ["SkillDeckTelemetry"]
        )
    ]
)
```

- [ ] **Step 2: Write a failing bootstrap test**

Create `Tests/SkillDeckCoreTests/BootstrapTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore

final class BootstrapTests: XCTestCase {
    func testPackageExposesVersionedAppIdentity() {
        XCTAssertEqual(AppIdentity.name, "SkillDeck")
        XCTAssertEqual(AppIdentity.minimumSupportedMacOSMajorVersion, 14)
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run:

```bash
rtk swift test --filter BootstrapTests
```

Expected: fail with `cannot find 'AppIdentity' in scope`.

- [ ] **Step 4: Implement the minimal core identity**

Create `Sources/SkillDeckCore/Models/SkillModels.swift` with this temporary content:

```swift
public enum AppIdentity {
    public static let name = "SkillDeck"
    public static let minimumSupportedMacOSMajorVersion = 14
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run:

```bash
rtk swift test --filter BootstrapTests
```

Expected: `Executed 1 test, with 0 failures`.

- [ ] **Step 6: Create the Xcode macOS app project**

Create `SkillDeck.xcodeproj` with Xcode's macOS App template:

```text
Product Name: SkillDeck
Team: None for local development
Organization Identifier: com.volvox
Interface: SwiftUI
Language: Swift
Minimum Deployment: macOS 14.0
Use SwiftData: Off
Include Tests: On
```

Add the local package at repository root to the app project. Link these package products to the app target:

```text
SkillDeckCore
SkillDeckSources
SkillDeckAgents
SkillDeckPersistence
SkillDeckServices
SkillDeckTelemetry
```

Create `SkillDeck/SkillDeck.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 7: Add a minimal app shell**

Create `SkillDeck/SkillDeckApp.swift`:

```swift
import SwiftUI

@main
struct SkillDeckApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }

        Settings {
            Text("Settings")
                .padding()
        }
    }
}
```

Create `SkillDeck/Views/MainWindowView.swift`:

```swift
import SwiftUI

struct MainWindowView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Text("Discover")
                Text("Installed")
                Text("Sources")
                Text("Updates")
                Text("Logs")
                Text("Settings")
            }
        } content: {
            Text("Select a section")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } detail: {
            Text("No skill selected")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("SkillDeck")
    }
}
```

- [ ] **Step 8: Build package and app**

Run:

```bash
rtk swift test --filter BootstrapTests
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' build
```

Expected: both commands succeed.

- [ ] **Step 9: Commit**

```bash
rtk git add Package.swift SkillDeck.xcodeproj SkillDeck Tests Sources
rtk git commit -m "chore: bootstrap SkillDeck project"
```

---

### Task 2: Core Models, Errors, Hashing, And Path Safety

**Files:**
- Modify: `Sources/SkillDeckCore/Models/SkillModels.swift`
- Create: `Sources/SkillDeckCore/Models/AgentModels.swift`
- Create: `Sources/SkillDeckCore/Models/SettingsModels.swift`
- Create: `Sources/SkillDeckCore/SkillDeckError.swift`
- Create: `Sources/SkillDeckCore/Hashing/ContentHasher.swift`
- Create: `Sources/SkillDeckCore/Paths/PathSafetyValidator.swift`
- Create: `Tests/SkillDeckCoreTests/CoreModelTests.swift`
- Create: `Tests/SkillDeckCoreTests/PathSafetyValidatorTests.swift`

- [ ] **Step 1: Write failing model and path-safety tests**

Create `Tests/SkillDeckCoreTests/CoreModelTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore

final class CoreModelTests: XCTestCase {
    func testSkillIdentityCombinesSourceAndName() {
        let skill = SkillSummary(
            id: SkillID("github/awesome-copilot/typescript-mcp-server-generator"),
            name: "typescript-mcp-server-generator",
            description: "Generates MCP servers",
            source: SkillSourceReference(kind: .github, location: "github/awesome-copilot", trusted: true),
            installCount: 10_611,
            tags: ["typescript"],
            lastUpdated: nil
        )

        XCTAssertEqual(skill.id.rawValue, "github/awesome-copilot/typescript-mcp-server-generator")
        XCTAssertEqual(skill.source.kind, .github)
        XCTAssertTrue(skill.source.trusted)
    }

    func testHasherProducesStableSHA256() throws {
        let digest = ContentHasher.sha256Hex(Data("SkillDeck".utf8))
        XCTAssertEqual(digest.count, 64)
        XCTAssertEqual(digest, ContentHasher.sha256Hex(Data("SkillDeck".utf8)))
    }
}
```

Create `Tests/SkillDeckCoreTests/PathSafetyValidatorTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore

final class PathSafetyValidatorTests: XCTestCase {
    func testRejectsTraversalOutsideApprovedFolder() throws {
        let approved = URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true)
        let candidate = URL(fileURLWithPath: "/Users/test/.codex/skills/../config.toml")

        XCTAssertThrowsError(try PathSafetyValidator.validateWriteDestination(candidate, inside: approved)) { error in
            XCTAssertEqual(error as? SkillDeckError, .pathTraversalRejected(candidate.path))
        }
    }

    func testAllowsChildInsideApprovedFolder() throws {
        let approved = URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true)
        let candidate = URL(fileURLWithPath: "/Users/test/.codex/skills/frontend-design/SKILL.md")

        let validated = try PathSafetyValidator.validateWriteDestination(candidate, inside: approved)
        XCTAssertEqual(validated.path, "/Users/test/.codex/skills/frontend-design/SKILL.md")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
rtk swift test --filter CoreModelTests
rtk swift test --filter PathSafetyValidatorTests
```

Expected: fail because `SkillSummary`, `ContentHasher`, `PathSafetyValidator`, and `SkillDeckError` do not exist.

- [ ] **Step 3: Implement core types**

Replace `Sources/SkillDeckCore/Models/SkillModels.swift`:

```swift
import Foundation

public enum AppIdentity {
    public static let name = "SkillDeck"
    public static let minimumSupportedMacOSMajorVersion = 14
}

public struct SkillID: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public enum SkillSourceKind: String, Codable, Sendable {
    case skillsSh
    case github
    case local
}

public struct SkillSourceReference: Hashable, Codable, Sendable {
    public let kind: SkillSourceKind
    public let location: String
    public let trusted: Bool

    public init(kind: SkillSourceKind, location: String, trusted: Bool) {
        self.kind = kind
        self.location = location
        self.trusted = trusted
    }
}

public struct SkillSummary: Hashable, Codable, Sendable, Identifiable {
    public let id: SkillID
    public let name: String
    public let description: String
    public let source: SkillSourceReference
    public let installCount: Int?
    public let tags: [String]
    public let lastUpdated: Date?

    public init(
        id: SkillID,
        name: String,
        description: String,
        source: SkillSourceReference,
        installCount: Int?,
        tags: [String],
        lastUpdated: Date?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.source = source
        self.installCount = installCount
        self.tags = tags
        self.lastUpdated = lastUpdated
    }
}

public struct SkillDetail: Hashable, Codable, Sendable {
    public let summary: SkillSummary
    public let readmeMarkdown: String
    public let skillMarkdown: String
    public let sourceCommit: String?
    public let contentHash: String
    public let relativePath: String

    public init(
        summary: SkillSummary,
        readmeMarkdown: String,
        skillMarkdown: String,
        sourceCommit: String?,
        contentHash: String,
        relativePath: String
    ) {
        self.summary = summary
        self.readmeMarkdown = readmeMarkdown
        self.skillMarkdown = skillMarkdown
        self.sourceCommit = sourceCommit
        self.contentHash = contentHash
        self.relativePath = relativePath
    }
}
```

Create `Sources/SkillDeckCore/Models/AgentModels.swift`:

```swift
import Foundation

public enum AgentTargetKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case claudeCode
    case codex
    case githubCopilot
    case genericFilesystem

    public var id: String { rawValue }
}

public enum InstallScope: String, Codable, Sendable {
    case global
    case project
}

public enum InstallMode: String, Codable, Sendable {
    case copy
}

public struct AgentTarget: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let kind: AgentTargetKind
    public var displayName: String
    public var installPath: URL
    public var scope: InstallScope
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        kind: AgentTargetKind,
        displayName: String,
        installPath: URL,
        scope: InstallScope,
        isEnabled: Bool
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.installPath = installPath
        self.scope = scope
        self.isEnabled = isEnabled
    }
}
```

Create `Sources/SkillDeckCore/Models/SettingsModels.swift`:

```swift
import Foundation

public enum AppearanceMode: String, Codable, Sendable {
    case system
    case light
    case dark
}

public enum TelemetryConsentState: String, Codable, Sendable {
    case notAsked
    case declined
    case granted
}

public struct UserSettings: Hashable, Codable, Sendable {
    public var appearanceMode: AppearanceMode
    public var sentryConsent: TelemetryConsentState
    public var amplitudeConsent: TelemetryConsentState
    public var autoUpdateTrustedSources: Bool

    public init(
        appearanceMode: AppearanceMode = .system,
        sentryConsent: TelemetryConsentState = .notAsked,
        amplitudeConsent: TelemetryConsentState = .notAsked,
        autoUpdateTrustedSources: Bool = true
    ) {
        self.appearanceMode = appearanceMode
        self.sentryConsent = sentryConsent
        self.amplitudeConsent = amplitudeConsent
        self.autoUpdateTrustedSources = autoUpdateTrustedSources
    }
}
```

Create `Sources/SkillDeckCore/SkillDeckError.swift`:

```swift
import Foundation

public enum SkillDeckError: Error, Equatable, Sendable, LocalizedError {
    case sourceUnavailable(String)
    case githubRateLimited
    case invalidSkillStructure(String)
    case folderGrantMissing(String)
    case folderGrantExpired(String)
    case writePermissionDenied(String)
    case pathTraversalRejected(String)
    case localModificationDetected(String)
    case backupFailed(String)
    case hashMismatchAfterWrite(expected: String, actual: String)
    case telemetryConsentMissing

    public var errorDescription: String? {
        switch self {
        case .sourceUnavailable(let source): "Source unavailable: \(source)"
        case .githubRateLimited: "GitHub rate limit reached."
        case .invalidSkillStructure(let reason): "Invalid skill structure: \(reason)"
        case .folderGrantMissing(let path): "Folder access is missing for \(path)."
        case .folderGrantExpired(let path): "Folder access expired for \(path)."
        case .writePermissionDenied(let path): "Write permission denied for \(path)."
        case .pathTraversalRejected(let path): "Unsafe path rejected: \(path)."
        case .localModificationDetected(let path): "Local modifications detected at \(path)."
        case .backupFailed(let path): "Backup failed for \(path)."
        case .hashMismatchAfterWrite: "The written file hash did not match the expected hash."
        case .telemetryConsentMissing: "Telemetry consent has not been granted."
        }
    }
}
```

Create `Sources/SkillDeckCore/Hashing/ContentHasher.swift`:

```swift
import CryptoKit
import Foundation

public enum ContentHasher {
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    public static func sha256Hex(_ string: String) -> String {
        sha256Hex(Data(string.utf8))
    }
}
```

Create `Sources/SkillDeckCore/Paths/PathSafetyValidator.swift`:

```swift
import Foundation

public enum PathSafetyValidator {
    public static func validateWriteDestination(_ candidate: URL, inside approvedFolder: URL) throws -> URL {
        let approved = approvedFolder.standardizedFileURL.resolvingSymlinksInPath()
        let target = candidate.standardizedFileURL.resolvingSymlinksInPath()
        let approvedPath = approved.path.hasSuffix("/") ? approved.path : approved.path + "/"

        guard target.path == approved.path || target.path.hasPrefix(approvedPath) else {
            throw SkillDeckError.pathTraversalRejected(candidate.path)
        }

        return target
    }
}
```

- [ ] **Step 4: Run tests**

```bash
rtk swift test --filter CoreModelTests
rtk swift test --filter PathSafetyValidatorTests
```

Expected: both test suites pass.

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/SkillDeckCore Tests/SkillDeckCoreTests
rtk git commit -m "feat: add core SkillDeck domain types"
```

---

### Task 3: Skill Manifest Parsing And Repository Scanning

**Files:**
- Create: `Sources/SkillDeckCore/Parsing/SkillManifestParser.swift`
- Create: `Sources/SkillDeckSources/LocalSkillSourceProvider.swift`
- Create: `Tests/SkillDeckSourcesTests/SkillManifestParserTests.swift`
- Create: `Tests/SkillDeckSourcesTests/LocalSkillSourceProviderTests.swift`

- [ ] **Step 1: Write failing parser tests**

Create `Tests/SkillDeckSourcesTests/SkillManifestParserTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class SkillManifestParserTests: XCTestCase {
    func testParsesNameAndDescriptionFromFrontmatter() throws {
        let markdown = """
        ---
        name: swiftui-helper
        description: Helps build SwiftUI views
        ---

        # SwiftUI Helper
        """

        let manifest = try SkillManifestParser.parse(markdown)

        XCTAssertEqual(manifest.name, "swiftui-helper")
        XCTAssertEqual(manifest.description, "Helps build SwiftUI views")
    }

    func testRejectsMissingDescription() {
        let markdown = """
        ---
        name: broken
        ---

        # Broken
        """

        XCTAssertThrowsError(try SkillManifestParser.parse(markdown)) { error in
            XCTAssertEqual(error as? SkillDeckError, .invalidSkillStructure("SKILL.md must define string name and description frontmatter."))
        }
    }
}
```

- [ ] **Step 2: Write failing scanner tests**

Create `Tests/SkillDeckSourcesTests/LocalSkillSourceProviderTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class LocalSkillSourceProviderTests: XCTestCase {
    func testScansSupportedSkillLayouts() async throws {
        let root = try TemporaryDirectory()
        try root.write("SKILL.md", """
        ---
        name: root-skill
        description: Root skill
        ---
        """)
        try root.write("skills/frontend/SKILL.md", """
        ---
        name: frontend
        description: Frontend skill
        ---
        """)
        try root.write(".agents/skills/codex/SKILL.md", """
        ---
        name: codex
        description: Codex skill
        ---
        """)

        let provider = LocalSkillSourceProvider()
        let skills = try await provider.scanRepository(at: root.url, source: SkillSourceReference(kind: .local, location: root.url.path, trusted: true))

        XCTAssertEqual(Set(skills.map(\.name)), ["root-skill", "frontend", "codex"])
    }
}

private struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func write(_ relativePath: String, _ content: String) throws {
        let destination = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: destination)
    }
}
```

- [ ] **Step 3: Run tests to verify failure**

```bash
rtk swift test --filter SkillManifestParserTests
rtk swift test --filter LocalSkillSourceProviderTests
```

Expected: fail because parser and provider do not exist.

- [ ] **Step 4: Implement parser and scanner**

Create `Sources/SkillDeckCore/Parsing/SkillManifestParser.swift`:

```swift
import Foundation

public struct SkillManifest: Hashable, Sendable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

public enum SkillManifestParser {
    public static func parse(_ markdown: String) throws -> SkillManifest {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "---", let endIndex = lines.dropFirst().firstIndex(of: "---") else {
            throw SkillDeckError.invalidSkillStructure("SKILL.md must start with YAML-style frontmatter.")
        }

        let metadataLines = lines[1..<endIndex]
        let pairs = Dictionary(uniqueKeysWithValues: metadataLines.compactMap { line -> (String, String)? in
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { return nil }
            return (parts[0], parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))
        })

        guard let name = pairs["name"], !name.isEmpty,
              let description = pairs["description"], !description.isEmpty else {
            throw SkillDeckError.invalidSkillStructure("SKILL.md must define string name and description frontmatter.")
        }

        return SkillManifest(name: name, description: description)
    }
}
```

Create `Sources/SkillDeckSources/LocalSkillSourceProvider.swift`:

```swift
import Foundation
import SkillDeckCore

public struct LocalSkillSourceProvider: Sendable {
    public init() {}

    public func scanRepository(at root: URL, source: SkillSourceReference) async throws -> [SkillSummary] {
        let candidates = try skillManifestURLs(inside: root)
        var summaries: [SkillSummary] = []

        for candidate in candidates {
            let markdown = try String(contentsOf: candidate, encoding: .utf8)
            let manifest = try SkillManifestParser.parse(markdown)
            let relativePath = candidate.path.replacingOccurrences(of: root.path + "/", with: "")
            summaries.append(
                SkillSummary(
                    id: SkillID("\(source.location)/\(manifest.name)"),
                    name: manifest.name,
                    description: manifest.description,
                    source: source,
                    installCount: nil,
                    tags: [],
                    lastUpdated: nil
                )
            )
            _ = relativePath
        }

        return summaries.sorted { $0.name < $1.name }
    }

    private func skillManifestURLs(inside root: URL) throws -> [URL] {
        let supportedRoots = [
            root,
            root.appendingPathComponent("skills"),
            root.appendingPathComponent(".claude/skills"),
            root.appendingPathComponent(".agents/skills")
        ]

        var results: [URL] = []
        for supportedRoot in supportedRoots where FileManager.default.fileExists(atPath: supportedRoot.path) {
            let enumerator = FileManager.default.enumerator(
                at: supportedRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let file = enumerator?.nextObject() as? URL {
                if file.lastPathComponent == "SKILL.md" {
                    results.append(file)
                }
            }
        }

        return Array(Set(results)).sorted { $0.path < $1.path }
    }
}
```

- [ ] **Step 5: Run tests**

```bash
rtk swift test --filter SkillManifestParserTests
rtk swift test --filter LocalSkillSourceProviderTests
```

Expected: parser and scanner tests pass.

- [ ] **Step 6: Commit**

```bash
rtk git add Sources/SkillDeckCore/Parsing Sources/SkillDeckSources Tests/SkillDeckSourcesTests
rtk git commit -m "feat: parse and scan local skill manifests"
```

---

### Task 4: skills.sh Search Provider

**Files:**
- Create: `Sources/SkillDeckSources/SkillSourceProviding.swift`
- Create: `Sources/SkillDeckSources/SkillsShSearchProvider.swift`
- Create: `Tests/SkillDeckSourcesTests/SkillsShSearchProviderTests.swift`

- [ ] **Step 1: Write failing provider tests**

Create `Tests/SkillDeckSourcesTests/SkillsShSearchProviderTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class SkillsShSearchProviderTests: XCTestCase {
    func testParsesPublicSearchResponse() async throws {
        let json = """
        {
          "query": "typescript",
          "skills": [
            {
              "id": "github/awesome-copilot/typescript-mcp-server-generator",
              "skillId": "typescript-mcp-server-generator",
              "name": "typescript-mcp-server-generator",
              "installs": 10611,
              "source": "github/awesome-copilot"
            }
          ],
          "count": 1
        }
        """.data(using: .utf8)!

        let client = MockHTTPClient(data: json, statusCode: 200)
        let provider = SkillsShSearchProvider(httpClient: client)

        let results = try await provider.search(query: "typescript", limit: 1)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "typescript-mcp-server-generator")
        XCTAssertEqual(results[0].installCount, 10611)
        XCTAssertEqual(results[0].source.location, "github/awesome-copilot")
        XCTAssertTrue(results[0].source.trusted)
    }
}

private struct MockHTTPClient: HTTPClient {
    let data: Data
    let statusCode: Int

    func data(for request: URLRequest) async throws -> HTTPResponse {
        HTTPResponse(data: data, statusCode: statusCode)
    }
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
rtk swift test --filter SkillsShSearchProviderTests
```

Expected: fail because `HTTPClient` and `SkillsShSearchProvider` do not exist.

- [ ] **Step 3: Implement HTTP protocol and provider**

Create `Sources/SkillDeckSources/SkillSourceProviding.swift`:

```swift
import Foundation
import SkillDeckCore

public struct HTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPClient {
    public init() {}

    public func data(for request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        return HTTPResponse(data: data, statusCode: statusCode)
    }
}

public protocol SkillSearchProviding: Sendable {
    func search(query: String, limit: Int) async throws -> [SkillSummary]
}
```

Create `Sources/SkillDeckSources/SkillsShSearchProvider.swift`:

```swift
import Foundation
import SkillDeckCore

public struct SkillsShSearchProvider: SkillSearchProviding {
    private let httpClient: HTTPClient
    private let baseURL: URL

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://skills.sh")!
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    public func search(query: String, limit: Int) async throws -> [SkillSummary] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            return []
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("/api/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        let request = URLRequest(url: components.url!)
        let response = try await httpClient.data(for: request)
        guard response.statusCode == 200 else {
            throw SkillDeckError.sourceUnavailable("skills.sh search returned HTTP \(response.statusCode)")
        }

        let decoded = try JSONDecoder().decode(SkillsShSearchResponse.self, from: response.data)
        return decoded.skills.map { item in
            SkillSummary(
                id: SkillID(item.id),
                name: item.name,
                description: "",
                source: SkillSourceReference(kind: .skillsSh, location: item.source, trusted: true),
                installCount: item.installs,
                tags: [],
                lastUpdated: nil
            )
        }
    }
}

private struct SkillsShSearchResponse: Decodable {
    let skills: [SkillsShSkill]
}

private struct SkillsShSkill: Decodable {
    let id: String
    let name: String
    let installs: Int
    let source: String
}
```

- [ ] **Step 4: Run tests**

```bash
rtk swift test --filter SkillsShSearchProviderTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/SkillDeckSources Tests/SkillDeckSourcesTests
rtk git commit -m "feat: add skills.sh search provider"
```

---

### Task 5: Public GitHub Source Provider

**Files:**
- Create: `Sources/SkillDeckSources/GitHubURLParser.swift`
- Create: `Sources/SkillDeckSources/GitHubRepositoryClient.swift`
- Create: `Sources/SkillDeckSources/GitHubSkillSourceProvider.swift`
- Create: `Tests/SkillDeckSourcesTests/GitHubURLParserTests.swift`
- Create: `Tests/SkillDeckSourcesTests/GitHubSkillSourceProviderTests.swift`

- [ ] **Step 1: Write failing URL parser tests**

Create `Tests/SkillDeckSourcesTests/GitHubURLParserTests.swift`:

```swift
import XCTest
@testable import SkillDeckSources

final class GitHubURLParserTests: XCTestCase {
    func testParsesHTTPSRepositoryURL() throws {
        let repo = try GitHubURLParser.parse("https://github.com/vercel-labs/agent-skills")
        XCTAssertEqual(repo.owner, "vercel-labs")
        XCTAssertEqual(repo.name, "agent-skills")
        XCTAssertNil(repo.ref)
    }

    func testParsesShorthandWithRef() throws {
        let repo = try GitHubURLParser.parse("vercel-labs/agent-skills#main")
        XCTAssertEqual(repo.owner, "vercel-labs")
        XCTAssertEqual(repo.name, "agent-skills")
        XCTAssertEqual(repo.ref, "main")
    }

    func testRejectsNonGitHubURL() {
        XCTAssertThrowsError(try GitHubURLParser.parse("https://example.com/repo"))
    }
}
```

- [ ] **Step 2: Write failing provider test**

Create `Tests/SkillDeckSourcesTests/GitHubSkillSourceProviderTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckSources

final class GitHubSkillSourceProviderTests: XCTestCase {
    func testBuildsSkillDetailFromFetchedRepositoryFiles() async throws {
        let files = [
            "skills/swiftui-helper/SKILL.md": """
            ---
            name: swiftui-helper
            description: Helps build SwiftUI views
            ---

            # Skill
            """,
            "skills/swiftui-helper/README.md": "# Readme"
        ]
        let client = MockGitHubRepositoryClient(files: files, commit: "abc123")
        let provider = GitHubSkillSourceProvider(client: client)

        let details = try await provider.scan(source: "owner/repo")

        XCTAssertEqual(details.count, 1)
        XCTAssertEqual(details[0].summary.name, "swiftui-helper")
        XCTAssertEqual(details[0].sourceCommit, "abc123")
        XCTAssertEqual(details[0].readmeMarkdown, "# Readme")
        XCTAssertEqual(details[0].relativePath, "skills/swiftui-helper/SKILL.md")
    }
}

private struct MockGitHubRepositoryClient: GitHubRepositoryFetching {
    let files: [String: String]
    let commit: String

    func fetchRepositoryFiles(_ repository: GitHubRepository) async throws -> GitHubRepositorySnapshot {
        GitHubRepositorySnapshot(repository: repository, commit: commit, files: files)
    }
}
```

- [ ] **Step 3: Run tests to verify failure**

```bash
rtk swift test --filter GitHubURLParserTests
rtk swift test --filter GitHubSkillSourceProviderTests
```

Expected: fail because GitHub source types do not exist.

- [ ] **Step 4: Implement GitHub parser and provider**

Create `Sources/SkillDeckSources/GitHubURLParser.swift`:

```swift
import Foundation
import SkillDeckCore

public struct GitHubRepository: Hashable, Sendable {
    public let owner: String
    public let name: String
    public let ref: String?

    public var slug: String { "\(owner)/\(name)" }
}

public enum GitHubURLParser {
    public static func parse(_ input: String) throws -> GitHubRepository {
        let parts = input.split(separator: "#", maxSplits: 1).map(String.init)
        let source = parts[0]
        let ref = parts.count == 2 ? parts[1] : nil

        if source.hasPrefix("https://github.com/") {
            let url = URL(string: source)!
            let pathParts = url.path.split(separator: "/").map(String.init)
            guard pathParts.count >= 2 else {
                throw SkillDeckError.invalidSkillStructure("GitHub URL must include owner and repository.")
            }
            return GitHubRepository(owner: pathParts[0], name: pathParts[1].replacingOccurrences(of: ".git", with: ""), ref: ref)
        }

        let shorthand = source.split(separator: "/").map(String.init)
        guard shorthand.count == 2, !shorthand[0].isEmpty, !shorthand[1].isEmpty else {
            throw SkillDeckError.invalidSkillStructure("Only public GitHub owner/repo sources are supported.")
        }
        return GitHubRepository(owner: shorthand[0], name: shorthand[1], ref: ref)
    }
}
```

Create `Sources/SkillDeckSources/GitHubRepositoryClient.swift`:

```swift
import Foundation
import SkillDeckCore

public struct GitHubRepositorySnapshot: Sendable {
    public let repository: GitHubRepository
    public let commit: String
    public let files: [String: String]

    public init(repository: GitHubRepository, commit: String, files: [String : String]) {
        self.repository = repository
        self.commit = commit
        self.files = files
    }
}

public protocol GitHubRepositoryFetching: Sendable {
    func fetchRepositoryFiles(_ repository: GitHubRepository) async throws -> GitHubRepositorySnapshot
}

public struct GitHubRepositoryClient: GitHubRepositoryFetching {
    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient = URLSessionHTTPClient()) {
        self.httpClient = httpClient
    }

    public func fetchRepositoryFiles(_ repository: GitHubRepository) async throws -> GitHubRepositorySnapshot {
        throw SkillDeckError.sourceUnavailable("GitHub archive fetching is added after source parsing tests pass.")
    }
}
```

Create `Sources/SkillDeckSources/GitHubSkillSourceProvider.swift`:

```swift
import Foundation
import SkillDeckCore

public struct GitHubSkillSourceProvider: Sendable {
    private let client: GitHubRepositoryFetching

    public init(client: GitHubRepositoryFetching = GitHubRepositoryClient()) {
        self.client = client
    }

    public func scan(source: String) async throws -> [SkillDetail] {
        let repository = try GitHubURLParser.parse(source)
        let snapshot = try await client.fetchRepositoryFiles(repository)

        return try snapshot.files
            .filter { $0.key.hasSuffix("SKILL.md") }
            .map { path, markdown in
                let manifest = try SkillManifestParser.parse(markdown)
                let readmePath = path.replacingOccurrences(of: "SKILL.md", with: "README.md")
                let summary = SkillSummary(
                    id: SkillID("\(repository.slug)/\(manifest.name)"),
                    name: manifest.name,
                    description: manifest.description,
                    source: SkillSourceReference(kind: .github, location: repository.slug, trusted: true),
                    installCount: nil,
                    tags: [],
                    lastUpdated: nil
                )
                return SkillDetail(
                    summary: summary,
                    readmeMarkdown: snapshot.files[readmePath] ?? "",
                    skillMarkdown: markdown,
                    sourceCommit: snapshot.commit,
                    contentHash: ContentHasher.sha256Hex(markdown),
                    relativePath: path
                )
            }
            .sorted { $0.summary.name < $1.summary.name }
    }
}
```

- [ ] **Step 5: Run tests**

```bash
rtk swift test --filter GitHubURLParserTests
rtk swift test --filter GitHubSkillSourceProviderTests
```

Expected: parser and provider tests pass.

- [ ] **Step 6: Implement real public GitHub fetching**

Replace `fetchRepositoryFiles` in `GitHubRepositoryClient` with code that:

```swift
public func fetchRepositoryFiles(_ repository: GitHubRepository) async throws -> GitHubRepositorySnapshot {
    let ref = repository.ref ?? "HEAD"
    let treeURL = URL(string: "https://api.github.com/repos/\(repository.owner)/\(repository.name)/git/trees/\(ref)?recursive=1")!
    let treeResponse = try await httpClient.data(for: URLRequest(url: treeURL))

    if treeResponse.statusCode == 403 {
        throw SkillDeckError.githubRateLimited
    }
    guard treeResponse.statusCode == 200 else {
        throw SkillDeckError.sourceUnavailable("GitHub tree returned HTTP \(treeResponse.statusCode)")
    }

    let tree = try JSONDecoder().decode(GitHubTreeResponse.self, from: treeResponse.data)
    let markdownEntries = tree.tree.filter { entry in
        entry.type == "blob" && (entry.path.hasSuffix("SKILL.md") || entry.path.hasSuffix("README.md"))
    }

    var files: [String: String] = [:]
    for entry in markdownEntries {
        let rawURL = URL(string: "https://raw.githubusercontent.com/\(repository.owner)/\(repository.name)/\(tree.sha)/\(entry.path)")!
        let fileResponse = try await httpClient.data(for: URLRequest(url: rawURL))
        guard fileResponse.statusCode == 200 else { continue }
        files[entry.path] = String(data: fileResponse.data, encoding: .utf8) ?? ""
    }

    return GitHubRepositorySnapshot(repository: repository, commit: tree.sha, files: files)
}

private struct GitHubTreeResponse: Decodable {
    let sha: String
    let tree: [GitHubTreeEntry]
}

private struct GitHubTreeEntry: Decodable {
    let path: String
    let type: String
}
```

- [ ] **Step 7: Add an integration-style mocked HTTP test**

Add this test to `Tests/SkillDeckSourcesTests/GitHubSkillSourceProviderTests.swift`:

```swift
func testGitHubRepositoryClientFetchesTreeAndMarkdownFiles() async throws {
    let treeURL = "https://api.github.com/repos/owner/repo/git/trees/main?recursive=1"
    let skillURL = "https://raw.githubusercontent.com/owner/repo/tree123/skills/demo/SKILL.md"
    let readmeURL = "https://raw.githubusercontent.com/owner/repo/tree123/skills/demo/README.md"

    let treeJSON = """
    {
      "sha": "tree123",
      "tree": [
        { "path": "skills/demo/SKILL.md", "type": "blob" },
        { "path": "skills/demo/README.md", "type": "blob" },
        { "path": "assets/logo.png", "type": "blob" }
      ]
    }
    """.data(using: .utf8)!

    let client = RoutingHTTPClient(routes: [
        treeURL: HTTPResponse(data: treeJSON, statusCode: 200),
        skillURL: HTTPResponse(data: Data("---\nname: demo\ndescription: Demo\n---".utf8), statusCode: 200),
        readmeURL: HTTPResponse(data: Data("# Demo".utf8), statusCode: 200)
    ])
    let repositoryClient = GitHubRepositoryClient(httpClient: client)

    let snapshot = try await repositoryClient.fetchRepositoryFiles(
        GitHubRepository(owner: "owner", name: "repo", ref: "main")
    )

    XCTAssertEqual(snapshot.commit, "tree123")
    XCTAssertEqual(snapshot.files["skills/demo/SKILL.md"], "---\nname: demo\ndescription: Demo\n---")
    XCTAssertEqual(snapshot.files["skills/demo/README.md"], "# Demo")
    XCTAssertNil(snapshot.files["assets/logo.png"])
}
```

Add this test helper at the bottom of `Tests/SkillDeckSourcesTests/GitHubSkillSourceProviderTests.swift`:

```swift
private struct RoutingHTTPClient: HTTPClient {
    let routes: [String: HTTPResponse]

    func data(for request: URLRequest) async throws -> HTTPResponse {
        guard let url = request.url?.absoluteString, let response = routes[url] else {
            return HTTPResponse(data: Data(), statusCode: 404)
        }
        return response
    }
}
```

- [ ] **Step 8: Run source tests**

```bash
rtk swift test --filter SkillDeckSourcesTests
```

Expected: source tests pass.

- [ ] **Step 9: Commit**

```bash
rtk git add Sources/SkillDeckSources Tests/SkillDeckSourcesTests
rtk git commit -m "feat: scan public GitHub skill sources"
```

---

### Task 6: Agent Adapters And Folder Grants

**Files:**
- Create: `Sources/SkillDeckAgents/AgentTargetAdapter.swift`
- Create: `Sources/SkillDeckAgents/DefaultAgentAdapters.swift`
- Create: `Sources/SkillDeckServices/Security/FolderGrantStore.swift`
- Create: `Tests/SkillDeckAgentsTests/DefaultAgentAdaptersTests.swift`
- Create: `Tests/SkillDeckServicesTests/FolderGrantStoreTests.swift`

- [ ] **Step 1: Write failing adapter tests**

Create `Tests/SkillDeckAgentsTests/DefaultAgentAdaptersTests.swift`:

```swift
import XCTest
@testable import SkillDeckAgents
@testable import SkillDeckCore

final class DefaultAgentAdaptersTests: XCTestCase {
    func testCodexDefaultPathUsesCodexSkillsFolder() {
        let adapter = DefaultAgentAdapters.codex(homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true))
        XCTAssertEqual(adapter.displayName, "Codex")
        XCTAssertEqual(adapter.defaultGlobalInstallPath.path, "/Users/test/.codex/skills")
        XCTAssertEqual(adapter.projectInstallDirectoryName, ".agents/skills")
    }

    func testClaudeDefaultPathUsesClaudeSkillsFolder() {
        let adapter = DefaultAgentAdapters.claudeCode(homeDirectory: URL(fileURLWithPath: "/Users/test", isDirectory: true))
        XCTAssertEqual(adapter.defaultGlobalInstallPath.path, "/Users/test/.claude/skills")
        XCTAssertEqual(adapter.projectInstallDirectoryName, ".claude/skills")
    }
}
```

- [ ] **Step 2: Write failing grant tests**

Create `Tests/SkillDeckServicesTests/FolderGrantStoreTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class FolderGrantStoreTests: XCTestCase {
    func testMemoryGrantAllowsChildWrite() throws {
        let grants = InMemoryFolderGrantStore()
        let folder = URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true)
        grants.grant(folder)

        let destination = URL(fileURLWithPath: "/Users/test/.codex/skills/demo/SKILL.md")
        XCTAssertTrue(try grants.canWrite(to: destination))
    }

    func testMemoryGrantRejectsSiblingWrite() throws {
        let grants = InMemoryFolderGrantStore()
        grants.grant(URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true))

        XCTAssertFalse(try grants.canWrite(to: URL(fileURLWithPath: "/Users/test/.codex/config.toml")))
    }
}
```

- [ ] **Step 3: Run tests to verify failure**

```bash
rtk swift test --filter DefaultAgentAdaptersTests
rtk swift test --filter FolderGrantStoreTests
```

Expected: fail because adapters and grant store do not exist.

- [ ] **Step 4: Implement adapters**

Create `Sources/SkillDeckAgents/AgentTargetAdapter.swift`:

```swift
import Foundation
import SkillDeckCore

public struct AgentTargetAdapter: Hashable, Sendable {
    public let kind: AgentTargetKind
    public let displayName: String
    public let defaultGlobalInstallPath: URL
    public let projectInstallDirectoryName: String
    public let supportsEnableDisable: Bool

    public init(
        kind: AgentTargetKind,
        displayName: String,
        defaultGlobalInstallPath: URL,
        projectInstallDirectoryName: String,
        supportsEnableDisable: Bool
    ) {
        self.kind = kind
        self.displayName = displayName
        self.defaultGlobalInstallPath = defaultGlobalInstallPath
        self.projectInstallDirectoryName = projectInstallDirectoryName
        self.supportsEnableDisable = supportsEnableDisable
    }
}
```

Create `Sources/SkillDeckAgents/DefaultAgentAdapters.swift`:

```swift
import Foundation
import SkillDeckCore

public enum DefaultAgentAdapters {
    public static func claudeCode(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> AgentTargetAdapter {
        AgentTargetAdapter(
            kind: .claudeCode,
            displayName: "Claude Code",
            defaultGlobalInstallPath: homeDirectory.appendingPathComponent(".claude/skills", isDirectory: true),
            projectInstallDirectoryName: ".claude/skills",
            supportsEnableDisable: false
        )
    }

    public static func codex(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> AgentTargetAdapter {
        AgentTargetAdapter(
            kind: .codex,
            displayName: "Codex",
            defaultGlobalInstallPath: homeDirectory.appendingPathComponent(".codex/skills", isDirectory: true),
            projectInstallDirectoryName: ".agents/skills",
            supportsEnableDisable: false
        )
    }

    public static func githubCopilot(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> AgentTargetAdapter {
        AgentTargetAdapter(
            kind: .githubCopilot,
            displayName: "GitHub Copilot",
            defaultGlobalInstallPath: homeDirectory.appendingPathComponent(".copilot/skills", isDirectory: true),
            projectInstallDirectoryName: ".agents/skills",
            supportsEnableDisable: false
        )
    }
}
```

- [ ] **Step 5: Implement grant store protocol**

Create `Sources/SkillDeckServices/Security/FolderGrantStore.swift`:

```swift
import Foundation
import SkillDeckCore

public protocol FolderGrantChecking: Sendable {
    func canWrite(to destination: URL) throws -> Bool
}

public final class InMemoryFolderGrantStore: FolderGrantChecking, @unchecked Sendable {
    private var grantedFolders: [URL] = []

    public init() {}

    public func grant(_ folder: URL) {
        grantedFolders.append(folder.standardizedFileURL)
    }

    public func canWrite(to destination: URL) throws -> Bool {
        for folder in grantedFolders {
            if (try? PathSafetyValidator.validateWriteDestination(destination, inside: folder)) != nil {
                return true
            }
        }
        return false
    }
}
```

- [ ] **Step 6: Run tests**

```bash
rtk swift test --filter DefaultAgentAdaptersTests
rtk swift test --filter FolderGrantStoreTests
```

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
rtk git add Sources/SkillDeckAgents Sources/SkillDeckServices Tests/SkillDeckAgentsTests Tests/SkillDeckServicesTests
rtk git commit -m "feat: add agent adapters and folder grants"
```

---

### Task 7: SwiftData Persistence

**Files:**
- Create: `Sources/SkillDeckPersistence/SkillDeckSchema.swift`
- Create: `Sources/SkillDeckPersistence/SkillDeckRepository.swift`
- Create: `Tests/SkillDeckPersistenceTests/SkillDeckRepositoryTests.swift`

- [ ] **Step 1: Write failing repository test**

Create `Tests/SkillDeckPersistenceTests/SkillDeckRepositoryTests.swift`:

```swift
import SwiftData
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckPersistence

final class SkillDeckRepositoryTests: XCTestCase {
    func testSavesAndLoadsInstalledSkill() throws {
        let container = try ModelContainer(
            for: InstalledSkillRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SkillDeckRepository(modelContext: ModelContext(container))
        let record = InstalledSkillRecord(
            skillID: "github/example/demo",
            name: "demo",
            sourceLocation: "github/example",
            destinationPath: "/tmp/demo/SKILL.md",
            installedHash: "abc",
            sourceCommit: "123"
        )

        try repository.saveInstalledSkill(record)
        let loaded = try repository.installedSkills()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].skillID, "github/example/demo")
    }
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
rtk swift test --filter SkillDeckRepositoryTests
```

Expected: fail because persistence types do not exist.

- [ ] **Step 3: Implement SwiftData schema and repository**

Create `Sources/SkillDeckPersistence/SkillDeckSchema.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class InstalledSkillRecord {
    @Attribute(.unique) public var skillID: String
    public var name: String
    public var sourceLocation: String
    public var destinationPath: String
    public var installedHash: String
    public var sourceCommit: String?
    public var installedAt: Date
    public var lastCheckedAt: Date?

    public init(
        skillID: String,
        name: String,
        sourceLocation: String,
        destinationPath: String,
        installedHash: String,
        sourceCommit: String?,
        installedAt: Date = Date(),
        lastCheckedAt: Date? = nil
    ) {
        self.skillID = skillID
        self.name = name
        self.sourceLocation = sourceLocation
        self.destinationPath = destinationPath
        self.installedHash = installedHash
        self.sourceCommit = sourceCommit
        self.installedAt = installedAt
        self.lastCheckedAt = lastCheckedAt
    }
}

@Model
public final class LogEntryRecord {
    public var id: UUID
    public var category: String
    public var level: String
    public var message: String
    public var createdAt: Date

    public init(id: UUID = UUID(), category: String, level: String, message: String, createdAt: Date = Date()) {
        self.id = id
        self.category = category
        self.level = level
        self.message = message
        self.createdAt = createdAt
    }
}

@Model
public final class BackupRecord {
    public var id: UUID
    public var skillID: String
    public var backupPath: String
    public var originalPath: String
    public var oldHash: String
    public var newHash: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        skillID: String,
        backupPath: String,
        originalPath: String,
        oldHash: String,
        newHash: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.skillID = skillID
        self.backupPath = backupPath
        self.originalPath = originalPath
        self.oldHash = oldHash
        self.newHash = newHash
        self.createdAt = createdAt
    }
}
```

Create `Sources/SkillDeckPersistence/SkillDeckRepository.swift`:

```swift
import Foundation
import SwiftData

public final class SkillDeckRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func saveInstalledSkill(_ record: InstalledSkillRecord) throws {
        modelContext.insert(record)
        try modelContext.save()
    }

    public func installedSkills() throws -> [InstalledSkillRecord] {
        try modelContext.fetch(FetchDescriptor<InstalledSkillRecord>())
    }

    public func appendLog(_ record: LogEntryRecord) throws {
        modelContext.insert(record)
        try modelContext.save()
    }

    public func logs() throws -> [LogEntryRecord] {
        try modelContext.fetch(FetchDescriptor<LogEntryRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }
}
```

- [ ] **Step 4: Run tests**

```bash
rtk swift test --filter SkillDeckRepositoryTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/SkillDeckPersistence Tests/SkillDeckPersistenceTests
rtk git commit -m "feat: add SwiftData persistence records"
```

---

### Task 8: Logging And Consent-Gated Telemetry

**Files:**
- Create: `Sources/SkillDeckServices/Logging/AppLogService.swift`
- Create: `Sources/SkillDeckTelemetry/TelemetryConsentStore.swift`
- Create: `Sources/SkillDeckTelemetry/TelemetryClient.swift`
- Create: `Sources/SkillDeckTelemetry/SentryTelemetryClient.swift`
- Create: `Sources/SkillDeckTelemetry/AmplitudeTelemetryClient.swift`
- Create: `Tests/SkillDeckServicesTests/AppLogServiceTests.swift`
- Create: `Tests/SkillDeckTelemetryTests/TelemetryConsentTests.swift`

- [ ] **Step 1: Write failing telemetry tests**

Create `Tests/SkillDeckTelemetryTests/TelemetryConsentTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckTelemetry

final class TelemetryConsentTests: XCTestCase {
    func testNoEventsSentBeforeAmplitudeConsent() async {
        let sink = RecordingTelemetrySink()
        let client = ConsentGatedTelemetryClient(
            sink: sink,
            consent: TelemetryConsent(sentry: .declined, amplitude: .notAsked)
        )

        await client.track(.searchPerformed(queryLength: 6, resultCount: 2))

        XCTAssertEqual(await sink.events.count, 0)
    }

    func testEventSentAfterAmplitudeConsent() async {
        let sink = RecordingTelemetrySink()
        let client = ConsentGatedTelemetryClient(
            sink: sink,
            consent: TelemetryConsent(sentry: .declined, amplitude: .granted)
        )

        await client.track(.searchPerformed(queryLength: 6, resultCount: 2))

        XCTAssertEqual(await sink.events.count, 1)
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
rtk swift test --filter TelemetryConsentTests
```

Expected: fail because telemetry types do not exist.

- [ ] **Step 3: Implement telemetry wrapper interfaces**

Create `Sources/SkillDeckTelemetry/TelemetryClient.swift`:

```swift
import Foundation
import SkillDeckCore

public enum TelemetryEvent: Equatable, Sendable {
    case appLaunched
    case searchPerformed(queryLength: Int, resultCount: Int)
    case skillDetailOpened(sourceKind: SkillSourceKind)
    case skillInstalled(sourceKind: SkillSourceKind)
    case updateChecked(resultCount: Int)
    case skillUpdated(sourceKind: SkillSourceKind)
    case sourceAdded(sourceKind: SkillSourceKind)
    case errorOccurred(code: String)
}

public struct TelemetryConsent: Sendable {
    public var sentry: TelemetryConsentState
    public var amplitude: TelemetryConsentState

    public init(sentry: TelemetryConsentState, amplitude: TelemetryConsentState) {
        self.sentry = sentry
        self.amplitude = amplitude
    }
}

public protocol TelemetrySink: Sendable {
    func track(_ event: TelemetryEvent) async
}

public final actor RecordingTelemetrySink: TelemetrySink {
    public private(set) var events: [TelemetryEvent] = []

    public init() {}

    public func track(_ event: TelemetryEvent) async {
        events.append(event)
    }
}

public struct ConsentGatedTelemetryClient: Sendable {
    private let sink: TelemetrySink
    private let consent: TelemetryConsent

    public init(sink: TelemetrySink, consent: TelemetryConsent) {
        self.sink = sink
        self.consent = consent
    }

    public func track(_ event: TelemetryEvent) async {
        guard consent.amplitude == .granted else { return }
        await sink.track(event)
    }
}
```

Create `Sources/SkillDeckTelemetry/TelemetryConsentStore.swift`:

```swift
import Foundation
import SkillDeckCore

public struct TelemetryConsentStore: Sendable {
    public private(set) var consent: TelemetryConsent

    public init(consent: TelemetryConsent = TelemetryConsent(sentry: .notAsked, amplitude: .notAsked)) {
        self.consent = consent
    }
}
```

Create SDK wrapper files:

```swift
// Sources/SkillDeckTelemetry/SentryTelemetryClient.swift
import Foundation
import Sentry

public enum SentryTelemetryClient {
    public static func startIfConsented(dsn: String, consentGranted: Bool) {
        guard consentGranted else { return }
        SentrySDK.start { options in
            options.dsn = dsn
            options.sendDefaultPii = false
        }
    }
}
```

```swift
// Sources/SkillDeckTelemetry/AmplitudeTelemetryClient.swift
import AmplitudeSwift
import Foundation

public final class AmplitudeTelemetryClient: TelemetrySink, @unchecked Sendable {
    private let amplitude: Amplitude

    public init(apiKey: String) {
        amplitude = Amplitude(configuration: Configuration(apiKey: apiKey))
    }

    public func track(_ event: TelemetryEvent) async {
        amplitude.track(eventType: String(describing: event))
    }
}
```

- [ ] **Step 4: Run telemetry tests**

```bash
rtk swift test --filter TelemetryConsentTests
```

Expected: tests pass.

- [ ] **Step 5: Add app log service test and implementation**

Create `Tests/SkillDeckServicesTests/AppLogServiceTests.swift`:

```swift
import XCTest
@testable import SkillDeckServices

final class AppLogServiceTests: XCTestCase {
    func testMemoryLoggerStoresRedactedPathMessage() async {
        let logger = InMemoryAppLogService()
        await logger.info(category: "FileSystem", message: "Wrote /Users/bill/.codex/skills/demo/SKILL.md")

        let entries = await logger.entries()
        XCTAssertEqual(entries[0].message, "Wrote <path>/demo/SKILL.md")
    }
}
```

Create `Sources/SkillDeckServices/Logging/AppLogService.swift`:

```swift
import Foundation
import OSLog

public struct AppLogEntry: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let category: String
    public let level: String
    public let message: String
    public let createdAt: Date
}

public final actor InMemoryAppLogService {
    private var storedEntries: [AppLogEntry] = []

    public init() {}

    public func info(category: String, message: String) {
        storedEntries.insert(
            AppLogEntry(id: UUID(), category: category, level: "Info", message: redact(message), createdAt: Date()),
            at: 0
        )
    }

    public func entries() -> [AppLogEntry] {
        storedEntries
    }

    private func redact(_ message: String) -> String {
        message.replacingOccurrences(
            of: #"/Users/[^ ]+/(.+/[^/]+)$"#,
            with: "<path>/$1",
            options: .regularExpression
        )
    }
}
```

- [ ] **Step 6: Run logging and telemetry tests**

```bash
rtk swift test --filter AppLogServiceTests
rtk swift test --filter TelemetryConsentTests
```

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
rtk git add Sources/SkillDeckServices/Logging Sources/SkillDeckTelemetry Tests/SkillDeckServicesTests Tests/SkillDeckTelemetryTests Package.swift
rtk git commit -m "feat: add logging and consent-gated telemetry"
```

---

### Task 9: Install Preview, Conflict Detection, And Backups

**Files:**
- Create: `Sources/SkillDeckServices/Install/InstallPreviewService.swift`
- Create: `Sources/SkillDeckServices/Install/ConflictDetector.swift`
- Create: `Sources/SkillDeckServices/Install/BackupManager.swift`
- Create: `Tests/SkillDeckServicesTests/InstallPreviewServiceTests.swift`
- Create: `Tests/SkillDeckServicesTests/ConflictDetectorTests.swift`
- Create: `Tests/SkillDeckServicesTests/BackupManagerTests.swift`

- [ ] **Step 1: Write failing conflict tests**

Create `Tests/SkillDeckServicesTests/ConflictDetectorTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class ConflictDetectorTests: XCTestCase {
    func testReportsNoConflictWhenHashMatchesLastInstall() {
        let result = ConflictDetector.detect(currentHash: "abc", lastInstalledHash: "abc", destinationPath: "/tmp/SKILL.md")
        XCTAssertEqual(result, .none)
    }

    func testReportsLocalModificationWhenHashDiffers() {
        let result = ConflictDetector.detect(currentHash: "changed", lastInstalledHash: "abc", destinationPath: "/tmp/SKILL.md")
        XCTAssertEqual(result, .localModification(path: "/tmp/SKILL.md"))
    }
}
```

- [ ] **Step 2: Write failing install preview test**

Create `Tests/SkillDeckServicesTests/InstallPreviewServiceTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class InstallPreviewServiceTests: XCTestCase {
    func testPreviewFailsWhenFolderGrantIsMissing() async throws {
        let grants = InMemoryFolderGrantStore()
        let service = InstallPreviewService(folderGrants: grants)
        let detail = SkillDetail.fixture()
        let target = AgentTarget(
            kind: .codex,
            displayName: "Codex",
            installPath: URL(fileURLWithPath: "/Users/test/.codex/skills", isDirectory: true),
            scope: .global,
            isEnabled: true
        )

        await XCTAssertThrowsErrorAsync(try await service.previewInstall(skill: detail, targets: [target])) { error in
            XCTAssertEqual(error as? SkillDeckError, .folderGrantMissing("/Users/test/.codex/skills"))
        }
    }
}

private extension SkillDetail {
    static func fixture() -> SkillDetail {
        let summary = SkillSummary(
            id: SkillID("github/example/demo"),
            name: "demo",
            description: "Demo",
            source: SkillSourceReference(kind: .github, location: "github/example", trusted: true),
            installCount: nil,
            tags: [],
            lastUpdated: nil
        )
        return SkillDetail(
            summary: summary,
            readmeMarkdown: "",
            skillMarkdown: "---\nname: demo\ndescription: Demo\n---",
            sourceCommit: "123",
            contentHash: "abc",
            relativePath: "skills/demo/SKILL.md"
        )
    }
}

func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ validation: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        validation(error)
    }
}
```

- [ ] **Step 3: Run tests to verify failure**

```bash
rtk swift test --filter ConflictDetectorTests
rtk swift test --filter InstallPreviewServiceTests
```

Expected: fail because install services do not exist.

- [ ] **Step 4: Implement conflict and preview services**

Create `Sources/SkillDeckServices/Install/ConflictDetector.swift`:

```swift
import Foundation

public enum ConflictState: Equatable, Sendable {
    case none
    case localModification(path: String)
}

public enum ConflictDetector {
    public static func detect(currentHash: String, lastInstalledHash: String, destinationPath: String) -> ConflictState {
        currentHash == lastInstalledHash ? .none : .localModification(path: destinationPath)
    }
}
```

Create `Sources/SkillDeckServices/Install/InstallPreviewService.swift`:

```swift
import Foundation
import SkillDeckCore

public struct InstallPreview: Equatable, Sendable {
    public let skillName: String
    public let destinations: [URL]
    public let installMode: InstallMode
    public let backupRequired: Bool
}

public struct InstallPreviewService: Sendable {
    private let folderGrants: FolderGrantChecking

    public init(folderGrants: FolderGrantChecking) {
        self.folderGrants = folderGrants
    }

    public func previewInstall(skill: SkillDetail, targets: [AgentTarget]) async throws -> InstallPreview {
        var destinations: [URL] = []

        for target in targets where target.isEnabled {
            let destination = target.installPath
                .appendingPathComponent(skill.summary.name, isDirectory: true)
                .appendingPathComponent("SKILL.md")

            guard try folderGrants.canWrite(to: destination) else {
                throw SkillDeckError.folderGrantMissing(target.installPath.path)
            }
            destinations.append(destination)
        }

        return InstallPreview(
            skillName: skill.summary.name,
            destinations: destinations,
            installMode: .copy,
            backupRequired: true
        )
    }
}
```

- [ ] **Step 5: Implement backup manager with tests**

Create `Tests/SkillDeckServicesTests/BackupManagerTests.swift`:

```swift
import XCTest
@testable import SkillDeckServices

final class BackupManagerTests: XCTestCase {
    func testCreatesBackupCopy() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source/SKILL.md")
        let backupRoot = root.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content".write(to: source, atomically: true, encoding: .utf8)

        let manager = BackupManager(backupRoot: backupRoot)
        let backup = try manager.backupFile(at: source, skillID: "demo")

        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        XCTAssertEqual(try String(contentsOf: backup), "content")
    }
}
```

Create `Sources/SkillDeckServices/Install/BackupManager.swift`:

```swift
import Foundation
import SkillDeckCore

public struct BackupManager: Sendable {
    private let backupRoot: URL

    public init(backupRoot: URL) {
        self.backupRoot = backupRoot
    }

    public func backupFile(at source: URL, skillID: String) throws -> URL {
        let safeSkillID = skillID.replacingOccurrences(of: "/", with: "_")
        let destinationDirectory = backupRoot.appendingPathComponent(safeSkillID, isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let destination = destinationDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(source.pathExtension)

        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            throw SkillDeckError.backupFailed(source.path)
        }
    }
}
```

- [ ] **Step 6: Run tests**

```bash
rtk swift test --filter ConflictDetectorTests
rtk swift test --filter InstallPreviewServiceTests
rtk swift test --filter BackupManagerTests
```

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
rtk git add Sources/SkillDeckServices/Install Tests/SkillDeckServicesTests
rtk git commit -m "feat: add install preview conflict and backup services"
```

---

### Task 10: Copy Installer And Latest Backup Restore

**Files:**
- Create: `Sources/SkillDeckServices/Install/SkillInstaller.swift`
- Create: `Tests/SkillDeckServicesTests/SkillInstallerTests.swift`

- [ ] **Step 1: Write failing installer tests**

Create `Tests/SkillDeckServicesTests/SkillInstallerTests.swift`:

```swift
import XCTest
@testable import SkillDeckCore
@testable import SkillDeckServices

final class SkillInstallerTests: XCTestCase {
    func testCopiesSkillMarkdownIntoPreviewDestination() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = root.appendingPathComponent("demo/SKILL.md")
        let preview = InstallPreview(skillName: "demo", destinations: [destination], installMode: .copy, backupRequired: false)
        let installer = SkillInstaller()

        try await installer.install(skillMarkdown: "skill content", preview: preview)

        XCTAssertEqual(try String(contentsOf: destination), "skill content")
    }
}
```

- [ ] **Step 2: Run test to verify failure**

```bash
rtk swift test --filter SkillInstallerTests
```

Expected: fail because `SkillInstaller` does not exist.

- [ ] **Step 3: Implement copy installer**

Create `Sources/SkillDeckServices/Install/SkillInstaller.swift`:

```swift
import Foundation
import SkillDeckCore

public struct SkillInstaller: Sendable {
    public init() {}

    public func install(skillMarkdown: String, preview: InstallPreview) async throws {
        for destination in preview.destinations {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let temporaryFile = destination.deletingLastPathComponent()
                .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
            try skillMarkdown.write(to: temporaryFile, atomically: true, encoding: .utf8)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryFile, to: destination)
        }
    }

    public func restoreBackup(from backup: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: backup, to: destination)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
rtk swift test --filter SkillInstallerTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
rtk git add Sources/SkillDeckServices/Install/SkillInstaller.swift Tests/SkillDeckServicesTests/SkillInstallerTests.swift
rtk git commit -m "feat: copy skill files into approved destinations"
```

---

### Task 11: Update Checker And Auto-Update Policy

**Files:**
- Create: `Sources/SkillDeckServices/Update/AutoUpdatePolicy.swift`
- Create: `Sources/SkillDeckServices/Update/UpdateChecker.swift`
- Create: `Tests/SkillDeckServicesTests/AutoUpdatePolicyTests.swift`
- Create: `Tests/SkillDeckServicesTests/UpdateCheckerTests.swift`

- [ ] **Step 1: Write failing policy tests**

Create `Tests/SkillDeckServicesTests/AutoUpdatePolicyTests.swift`:

```swift
import XCTest
@testable import SkillDeckServices

final class AutoUpdatePolicyTests: XCTestCase {
    func testAllowsTrustedUnmodifiedSourceWithFolderGrant() {
        let decision = AutoUpdatePolicy.evaluate(
            isSourceTrusted: true,
            hasFolderGrant: true,
            hasLocalModifications: false,
            hasStableSourceHash: true,
            backupCanBeCreated: true
        )

        XCTAssertEqual(decision, .allow)
    }

    func testRefusesLocalModifications() {
        let decision = AutoUpdatePolicy.evaluate(
            isSourceTrusted: true,
            hasFolderGrant: true,
            hasLocalModifications: true,
            hasStableSourceHash: true,
            backupCanBeCreated: true
        )

        XCTAssertEqual(decision, .refuse(reason: "Local modifications require manual review."))
    }
}
```

- [ ] **Step 2: Run policy test to verify failure**

```bash
rtk swift test --filter AutoUpdatePolicyTests
```

Expected: fail because `AutoUpdatePolicy` does not exist.

- [ ] **Step 3: Implement policy**

Create `Sources/SkillDeckServices/Update/AutoUpdatePolicy.swift`:

```swift
import Foundation

public enum AutoUpdateDecision: Equatable, Sendable {
    case allow
    case refuse(reason: String)
}

public enum AutoUpdatePolicy {
    public static func evaluate(
        isSourceTrusted: Bool,
        hasFolderGrant: Bool,
        hasLocalModifications: Bool,
        hasStableSourceHash: Bool,
        backupCanBeCreated: Bool
    ) -> AutoUpdateDecision {
        guard isSourceTrusted else { return .refuse(reason: "Source is not trusted.") }
        guard hasFolderGrant else { return .refuse(reason: "Folder access is missing.") }
        guard !hasLocalModifications else { return .refuse(reason: "Local modifications require manual review.") }
        guard hasStableSourceHash else { return .refuse(reason: "Source hash is not stable.") }
        guard backupCanBeCreated else { return .refuse(reason: "Backup cannot be created.") }
        return .allow
    }
}
```

- [ ] **Step 4: Write update checker tests**

Create `Tests/SkillDeckServicesTests/UpdateCheckerTests.swift`:

```swift
import XCTest
@testable import SkillDeckServices

final class UpdateCheckerTests: XCTestCase {
    func testDetectsAvailableUpdateWhenHashChanges() {
        let result = UpdateChecker.compare(installedHash: "old", upstreamHash: "new")
        XCTAssertEqual(result, .updateAvailable)
    }

    func testReportsUpToDateWhenHashMatches() {
        let result = UpdateChecker.compare(installedHash: "same", upstreamHash: "same")
        XCTAssertEqual(result, .upToDate)
    }
}
```

Create `Sources/SkillDeckServices/Update/UpdateChecker.swift`:

```swift
import Foundation

public enum UpdateCheckResult: Equatable, Sendable {
    case upToDate
    case updateAvailable
}

public enum UpdateChecker {
    public static func compare(installedHash: String, upstreamHash: String) -> UpdateCheckResult {
        installedHash == upstreamHash ? .upToDate : .updateAvailable
    }
}
```

- [ ] **Step 5: Run update tests**

```bash
rtk swift test --filter AutoUpdatePolicyTests
rtk swift test --filter UpdateCheckerTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
rtk git add Sources/SkillDeckServices/Update Tests/SkillDeckServicesTests
rtk git commit -m "feat: add update checking policy"
```

---

### Task 12: Dependency Container And View Models

**Files:**
- Create: `SkillDeck/App/DependencyContainer.swift`
- Create: `SkillDeck/ViewModels/DiscoverViewModel.swift`
- Create: `SkillDeck/ViewModels/InstalledViewModel.swift`
- Create: `SkillDeck/ViewModels/SourcesViewModel.swift`
- Create: `SkillDeck/ViewModels/UpdatesViewModel.swift`
- Create: `SkillDeck/ViewModels/LogsViewModel.swift`
- Create: `SkillDeckTests/DiscoverViewModelTests.swift`

- [ ] **Step 1: Write failing Discover view-model test**

Create app test file `SkillDeckTests/DiscoverViewModelTests.swift`:

```swift
import XCTest
@testable import SkillDeck
import SkillDeckCore
import SkillDeckSources

@MainActor
final class DiscoverViewModelTests: XCTestCase {
    func testSearchStoresResults() async {
        let provider = MockSearchProvider(results: [
            SkillSummary(
                id: SkillID("source/demo"),
                name: "demo",
                description: "Demo",
                source: SkillSourceReference(kind: .skillsSh, location: "source", trusted: true),
                installCount: 1,
                tags: [],
                lastUpdated: nil
            )
        ])
        let viewModel = DiscoverViewModel(searchProvider: provider)

        await viewModel.search("demo")

        XCTAssertEqual(viewModel.results.map(\.name), ["demo"])
        XCTAssertNil(viewModel.errorMessage)
    }
}

private struct MockSearchProvider: SkillSearchProviding {
    let results: [SkillSummary]

    func search(query: String, limit: Int) async throws -> [SkillSummary] {
        results
    }
}
```

- [ ] **Step 2: Run app test to verify failure**

```bash
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' test -only-testing:SkillDeckTests/DiscoverViewModelTests
```

Expected: fail because `DiscoverViewModel` does not exist.

- [ ] **Step 3: Implement dependency container and discover view model**

Create `SkillDeck/App/DependencyContainer.swift`:

```swift
import Foundation
import SkillDeckSources

@MainActor
final class DependencyContainer: ObservableObject {
    let searchProvider: SkillSearchProviding

    init(searchProvider: SkillSearchProviding = SkillsShSearchProvider()) {
        self.searchProvider = searchProvider
    }
}
```

Create `SkillDeck/ViewModels/DiscoverViewModel.swift`:

```swift
import Foundation
import SkillDeckCore
import SkillDeckSources

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published private(set) var results: [SkillSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let searchProvider: SkillSearchProviding

    init(searchProvider: SkillSearchProviding) {
        self.searchProvider = searchProvider
    }

    func search(_ query: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            results = try await searchProvider.search(query: query, limit: 25)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }
}
```

Create section view models for the other tabs:

```swift
// SkillDeck/ViewModels/InstalledViewModel.swift
import Foundation

@MainActor
final class InstalledViewModel: ObservableObject {
    @Published var searchText = ""
}
```

```swift
// SkillDeck/ViewModels/SourcesViewModel.swift
import Foundation

@MainActor
final class SourcesViewModel: ObservableObject {
    @Published var sourceURLText = ""
}
```

```swift
// SkillDeck/ViewModels/UpdatesViewModel.swift
import Foundation

@MainActor
final class UpdatesViewModel: ObservableObject {
    @Published var isCheckingForUpdates = false
}
```

```swift
// SkillDeck/ViewModels/LogsViewModel.swift
import Foundation

@MainActor
final class LogsViewModel: ObservableObject {
    @Published var filterText = ""
}
```

- [ ] **Step 4: Run app tests**

```bash
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' test -only-testing:SkillDeckTests/DiscoverViewModelTests
```

Expected: test passes.

- [ ] **Step 5: Commit**

```bash
rtk git add SkillDeck/App SkillDeck/ViewModels SkillDeckTests
rtk git commit -m "feat: add app dependencies and view models"
```

---

### Task 13: Finder-Style Main Window And Inspector UI

**Files:**
- Modify: `SkillDeck/Views/MainWindowView.swift`
- Create: `SkillDeck/Views/DiscoverView.swift`
- Create: `SkillDeck/Views/InstalledView.swift`
- Create: `SkillDeck/Views/SourcesView.swift`
- Create: `SkillDeck/Views/UpdatesView.swift`
- Create: `SkillDeck/Views/LogsView.swift`
- Create: `SkillDeck/Views/SkillInspectorView.swift`

- [ ] **Step 1: Add UI selection model**

Add this enum to `SkillDeck/Views/MainWindowView.swift` above `MainWindowView`:

```swift
private enum SidebarSelection: String, CaseIterable, Identifiable {
    case discover = "Discover"
    case installed = "Installed"
    case sources = "Sources"
    case updates = "Updates"
    case logs = "Logs"
    case settings = "Settings"

    var id: String { rawValue }
}
```

- [ ] **Step 2: Replace main window with sidebar/list/inspector layout**

Replace `MainWindowView`:

```swift
import SwiftUI

struct MainWindowView: View {
    @State private var selection: SidebarSelection? = .discover
    @StateObject private var dependencies = DependencyContainer()

    var body: some View {
        NavigationSplitView {
            List(SidebarSelection.allCases, selection: $selection) { item in
                Text(LocalizedStringKey(item.rawValue))
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            contentView
                .frame(minWidth: 420)
        } detail: {
            SkillInspectorView()
                .frame(minWidth: 320)
        }
        .environmentObject(dependencies)
        .navigationTitle("SkillDeck")
    }

    @ViewBuilder
    private var contentView: some View {
        switch selection {
        case .discover:
            DiscoverView(viewModel: DiscoverViewModel(searchProvider: dependencies.searchProvider))
        case .installed:
            InstalledView(viewModel: InstalledViewModel())
        case .sources:
            SourcesView(viewModel: SourcesViewModel())
        case .updates:
            UpdatesView(viewModel: UpdatesViewModel())
        case .logs:
            LogsView(viewModel: LogsViewModel())
        case .settings:
            Text("Open Settings from the app menu.")
                .foregroundStyle(.secondary)
        case nil:
            Text("Select a section.")
                .foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 3: Create section views**

Create `SkillDeck/Views/DiscoverView.swift`:

```swift
import SkillDeckCore
import SwiftUI

struct DiscoverView: View {
    @StateObject var viewModel: DiscoverViewModel
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            List(viewModel.results) { skill in
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name).font(.headline)
                    Text(skill.source.location).font(.caption).foregroundStyle(.secondary)
                    if let installCount = skill.installCount {
                        Text("\(installCount) installs").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .overlay {
                if viewModel.results.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView("Search skills", systemImage: "magnifyingglass", description: Text("Find skills from skills.sh."))
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search skills", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await viewModel.search(query) }
                }
            Button("Refresh") {
                Task { await viewModel.search(query) }
            }
            .disabled(query.count < 2 || viewModel.isLoading)
        }
        .padding()
    }
}
```

Create simple section views:

```swift
// SkillDeck/Views/InstalledView.swift
import SwiftUI

struct InstalledView: View {
    @StateObject var viewModel: InstalledViewModel

    var body: some View {
        ContentUnavailableView("No installed skills", systemImage: "tray", description: Text("Installed skills will appear here."))
    }
}
```

```swift
// SkillDeck/Views/SourcesView.swift
import SwiftUI

struct SourcesView: View {
    @StateObject var viewModel: SourcesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("GitHub repository URL", text: $viewModel.sourceURLText)
                .textFieldStyle(.roundedBorder)
            Button("Add Source") {}
                .disabled(viewModel.sourceURLText.isEmpty)
            Spacer()
        }
        .padding()
    }
}
```

```swift
// SkillDeck/Views/UpdatesView.swift
import SwiftUI

struct UpdatesView: View {
    @StateObject var viewModel: UpdatesViewModel

    var body: some View {
        ContentUnavailableView("No updates", systemImage: "arrow.clockwise", description: Text("Update checks will appear here."))
    }
}
```

```swift
// SkillDeck/Views/LogsView.swift
import SwiftUI

struct LogsView: View {
    @StateObject var viewModel: LogsViewModel

    var body: some View {
        VStack {
            TextField("Filter logs", text: $viewModel.filterText)
                .textFieldStyle(.roundedBorder)
                .padding()
            ContentUnavailableView("No logs", systemImage: "doc.text.magnifyingglass", description: Text("App activity will appear here."))
        }
    }
}
```

```swift
// SkillDeck/Views/SkillInspectorView.swift
import SwiftUI

struct SkillInspectorView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No skill selected")
                .font(.headline)
            Text("Select a skill to preview metadata, installation targets, and update state.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
```

- [ ] **Step 4: Build and inspect**

```bash
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' build
```

Expected: build succeeds and main window shows the sidebar/list/inspector structure.

- [ ] **Step 5: Commit**

```bash
rtk git add SkillDeck/Views
rtk git commit -m "feat: add Finder-style SkillDeck shell"
```

---

### Task 14: Install, Conflict, Consent, And Settings Sheets

**Files:**
- Create: `SkillDeck/Views/InstallPreviewSheet.swift`
- Create: `SkillDeck/Views/ConflictResolutionSheet.swift`
- Create: `SkillDeck/Views/ConsentSheet.swift`
- Create: `SkillDeck/Settings/SkillDeckSettingsView.swift`
- Modify: `SkillDeck/SkillDeckApp.swift`
- Create: `SkillDeck/App/SkillDeckCommands.swift`

- [ ] **Step 1: Add install preview sheet**

Create `SkillDeck/Views/InstallPreviewSheet.swift`:

```swift
import SkillDeckServices
import SwiftUI

struct InstallPreviewSheet: View {
    let preview: InstallPreview
    let onCancel: () -> Void
    let onInstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install \(preview.skillName)")
                .font(.title2)
            Text("Mode: Copy")
                .foregroundStyle(.secondary)
            List(preview.destinations, id: \.path) { destination in
                Text(destination.path)
                    .font(.system(.body, design: .monospaced))
            }
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Install", action: onInstall)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560, height: 360)
    }
}
```

- [ ] **Step 2: Add conflict sheet**

Create `SkillDeck/Views/ConflictResolutionSheet.swift`:

```swift
import SwiftUI

struct ConflictResolutionSheet: View {
    let path: String
    let keepLocal: () -> Void
    let backupAndOverwrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local changes detected")
                .font(.title2)
            Text(path)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("SkillDeck will not overwrite this file unless you choose to create a backup first.")
            HStack {
                Button("Keep Local", action: keepLocal)
                Spacer()
                Button("Back Up and Overwrite", action: backupAndOverwrite)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 520)
    }
}
```

- [ ] **Step 3: Add consent sheet**

Create `SkillDeck/Views/ConsentSheet.swift`:

```swift
import SwiftUI

struct ConsentSheet: View {
    @Binding var sentryEnabled: Bool
    @Binding var amplitudeEnabled: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy")
                .font(.title2)
            Toggle("Enable crash reporting with Sentry", isOn: $sentryEnabled)
            Toggle("Enable anonymous product analytics with Amplitude", isOn: $amplitudeEnabled)
            Text("SkillDeck never sends skill contents, private repository URLs, or raw local file paths.")
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Continue", action: onContinue)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 520)
    }
}
```

- [ ] **Step 4: Add Settings scene**

Create `SkillDeck/Settings/SkillDeckSettingsView.swift`:

```swift
import SwiftUI

struct SkillDeckSettingsView: View {
    var body: some View {
        TabView {
            Form {
                Toggle("Enable background update checks", isOn: .constant(true))
                Toggle("Confirm before installing skills", isOn: .constant(true))
            }
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Toggle("Auto-update trusted sources", isOn: .constant(true))
                Text("Auto-updates stop when local modifications or missing folder grants are detected.")
                    .foregroundStyle(.secondary)
            }
            .tabItem { Label("Updates", systemImage: "arrow.clockwise") }

            Form {
                Toggle("Sentry crash reporting", isOn: .constant(false))
                Toggle("Amplitude analytics", isOn: .constant(false))
            }
            .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .padding()
        .frame(width: 620, height: 420)
    }
}
```

Modify `SkillDeck/SkillDeckApp.swift` Settings scene:

```swift
Settings {
    SkillDeckSettingsView()
}
```

- [ ] **Step 5: Add keyboard commands**

Create `SkillDeck/App/SkillDeckCommands.swift`:

```swift
import SwiftUI

struct SkillDeckCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Refresh") {}
                .keyboardShortcut("r", modifiers: [.command])
            Button("Update All") {}
                .keyboardShortcut("u", modifiers: [.command, .shift])
        }
    }
}
```

Modify `SkillDeckApp`:

```swift
.commands {
    SkillDeckCommands()
}
```

- [ ] **Step 6: Build app**

```bash
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 7: Commit**

```bash
rtk git add SkillDeck/Views SkillDeck/Settings SkillDeck/App SkillDeck/SkillDeckApp.swift
rtk git commit -m "feat: add install conflict consent and settings UI"
```

---

### Task 15: Documentation And Verification

**Files:**
- Modify: `README.md`
- Create: `docs/architecture.md`
- Create: `docs/integrations/skills-sh.md`
- Create: `docs/integrations/telemetry.md`

- [ ] **Step 1: Update README**

Replace `README.md`:

```markdown
# SkillDeck

SkillDeck is a native macOS app for discovering, installing, updating, and managing AI-agent skills across Claude Code, Codex, GitHub Copilot, and generic filesystem targets.

## Requirements

- macOS 14 or newer
- Xcode 26.3 or newer
- Swift 6.2 or newer

## Build

```bash
rtk swift test
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' build
```

## Test

```bash
rtk swift test
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' test
```

## MVP Scope

- Search skills.sh through the public `/api/search` endpoint.
- Scan public GitHub repositories for `SKILL.md`.
- Preview copy installs into user-approved folders.
- Detect local modifications with content hashes.
- Create backups before replacing files.
- Show logs and key settings.
- Gate Sentry and Amplitude behind explicit user consent.
```

- [ ] **Step 2: Add architecture doc**

Create `docs/architecture.md`:

```markdown
# Architecture

SkillDeck separates SwiftUI views from business logic.

- `SkillDeckCore`: domain models, errors, hashing, path safety, parsing primitives.
- `SkillDeckSources`: skills.sh, GitHub, and local source providers.
- `SkillDeckAgents`: adapter definitions for agent targets.
- `SkillDeckPersistence`: SwiftData records and repositories.
- `SkillDeckServices`: install, update, backup, grants, logging workflows.
- `SkillDeckTelemetry`: consent-gated Sentry and Amplitude wrappers.
- `SkillDeck`: macOS SwiftUI app shell.

Services depend on protocols so tests can use temporary directories, mock HTTP responses, and recording telemetry sinks.
```

- [ ] **Step 3: Add skills.sh integration doc**

Create `docs/integrations/skills-sh.md`:

```markdown
# skills.sh Integration

SkillDeck uses skills.sh as a discovery index.

The MVP calls:

```text
GET https://skills.sh/api/search?q=<query>&limit=<n>
```

The authenticated `/api/v1/*` endpoints require Vercel OIDC and are not used by the MVP.

Install content comes from public GitHub repositories resolved from search results or user-added sources.

If public search fails, the app still supports adding public GitHub sources directly.
```

- [ ] **Step 4: Add telemetry doc**

Create `docs/integrations/telemetry.md`:

```markdown
# Telemetry

SkillDeck wires Sentry and Amplitude but keeps both disabled until explicit consent.

Defaults:

- Sentry crash reporting: off
- Amplitude analytics: off
- Skill contents: never sent
- Raw local file paths: never sent
- Private repository URLs: never sent

Tests assert no analytics event reaches a telemetry sink before consent.
```

- [ ] **Step 5: Run full verification**

Run:

```bash
rtk swift test
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' build
rtk xcodebuild -project SkillDeck.xcodeproj -scheme SkillDeck -destination 'platform=macOS' test
```

Expected: all package tests pass, app build succeeds, app tests pass.

- [ ] **Step 6: Commit**

```bash
rtk git add README.md docs
rtk git commit -m "docs: document SkillDeck MVP"
```

---

## Self-Review Checklist

- Spec coverage: The plan maps to discovery, GitHub sources, copy installs, global/project targets, sandbox folder grants, conflict detection, backups, updates, SwiftData, logs, telemetry consent, UI shell, settings, and docs.
- Deferred scope: Symlinks, private GitHub auth, backend proxy, full localization packs, menu bar, launch at login, full backup timeline, and App Store metadata remain outside MVP.
- Test coverage: Each non-UI service has a failing test before implementation.
- Type consistency: Shared names are `SkillSummary`, `SkillDetail`, `SkillSourceReference`, `AgentTarget`, `InstallPreview`, `ConflictState`, `AutoUpdatePolicy`, and `TelemetryEvent`.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-14-skilldeck-mvp.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
