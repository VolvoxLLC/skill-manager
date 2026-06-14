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
