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
