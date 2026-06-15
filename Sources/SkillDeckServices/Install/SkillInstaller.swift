import Foundation
import SkillDeckCore

public struct SkillInstaller: Sendable {
    public init() {}

    public func install(skillMarkdown: String, preview: InstallPreview, expectedContentHash: String? = nil) async throws {
        if let expectedContentHash {
            let actualContentHash = ContentHasher.sha256Hex(skillMarkdown)
            guard actualContentHash == expectedContentHash else {
                throw SkillDeckError.hashMismatchAfterWrite(expected: expectedContentHash, actual: actualContentHash)
            }
        }

        for destination in preview.destinations {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let temporaryFile = destination.deletingLastPathComponent()
                .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
            do {
                try skillMarkdown.write(to: temporaryFile, atomically: true, encoding: .utf8)
            } catch {
                try? FileManager.default.removeItem(at: temporaryFile)
                throw error
            }

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryFile, to: destination)

            if let expectedContentHash {
                let actualHash = ContentHasher.sha256Hex(try Data(contentsOf: destination))
                guard actualHash == expectedContentHash else {
                    throw SkillDeckError.hashMismatchAfterWrite(expected: expectedContentHash, actual: actualHash)
                }
            }
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
