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
