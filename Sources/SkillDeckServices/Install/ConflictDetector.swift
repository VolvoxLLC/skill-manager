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
