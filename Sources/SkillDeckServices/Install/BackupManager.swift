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
