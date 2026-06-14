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
