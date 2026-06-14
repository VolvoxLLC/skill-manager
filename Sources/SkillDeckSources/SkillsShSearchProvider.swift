import Foundation
import SkillDeckCore

public struct SkillsShSearchProvider: SkillSearchProviding {
    private let httpClient: HTTPClient
    private let baseURL: URL

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://skills.sh")!
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    public func search(query: String, limit: Int) async throws -> [SkillSummary] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            return []
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("/api/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        let request = URLRequest(url: components.url!)
        let response = try await httpClient.data(for: request)
        guard response.statusCode == 200 else {
            throw SkillDeckError.sourceUnavailable("skills.sh search returned HTTP \(response.statusCode)")
        }

        let decoded = try JSONDecoder().decode(SkillsShSearchResponse.self, from: response.data)
        return decoded.skills.map { item in
            SkillSummary(
                id: SkillID(item.id),
                name: item.name,
                description: "",
                source: SkillSourceReference(kind: .skillsSh, location: item.source, trusted: true),
                installCount: item.installs,
                tags: [],
                lastUpdated: nil
            )
        }
    }
}

private struct SkillsShSearchResponse: Decodable {
    let skills: [SkillsShSkill]
}

private struct SkillsShSkill: Decodable {
    let id: String
    let name: String
    let installs: Int
    let source: String
}
