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
