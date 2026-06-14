import Foundation

public struct SkillManifest: Hashable, Sendable {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

public enum SkillManifestParser {
    public static func parse(_ markdown: String) throws -> SkillManifest {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "---", let endIndex = lines.dropFirst().firstIndex(of: "---") else {
            throw SkillDeckError.invalidSkillStructure("SKILL.md must start with YAML-style frontmatter.")
        }

        let metadataLines = lines[1..<endIndex]
        let pairs = Dictionary(
            metadataLines.compactMap { line -> (String, String)? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { return nil }
                return (parts[0], parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'")))
            },
            uniquingKeysWith: { _, latest in latest }
        )

        guard let name = pairs["name"], !name.isEmpty,
              let description = pairs["description"], !description.isEmpty else {
            throw SkillDeckError.invalidSkillStructure("SKILL.md must define string name and description frontmatter.")
        }

        return SkillManifest(name: name, description: description)
    }
}
