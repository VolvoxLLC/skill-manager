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
