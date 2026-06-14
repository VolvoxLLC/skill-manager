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
