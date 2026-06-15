import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import SkillDeckCore

/// Fetches the skills.sh "Trending" leaderboard.
///
/// skills.sh exposes no public JSON API for trending skills; its `/trending` page is rendered
/// with Next.js React Server Components. This provider requests the RSC payload
/// (`/trending?_rsc=1`) and extracts the embedded skill objects, which share the same shape as
/// the public search response. The format is undocumented, so parse failures degrade to an
/// empty list rather than propagating.
public struct SkillsShTrendingProvider: SkillTrendingProviding {
    private let httpClient: HTTPClient
    private let baseURL: URL

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://www.skills.sh")!
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    public func trending(limit: Int) async throws -> [SkillSummary] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/trending"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "_rsc", value: "1")]

        var request = URLRequest(url: components.url!)
        request.setValue("1", forHTTPHeaderField: "RSC")

        let response = try await httpClient.data(for: request)
        guard response.statusCode == 200 else {
            throw SkillDeckError.sourceUnavailable("skills.sh trending returned HTTP \(response.statusCode)")
        }

        let skills = Self.extractSkills(from: response.data)

        var bestByID: [String: SkillsShSkill] = [:]
        for skill in skills {
            let identifier = skill.identifier
            if let existing = bestByID[identifier], existing.installs >= skill.installs {
                continue
            }
            bestByID[identifier] = skill
        }

        return bestByID.values
            .sorted { $0.installs > $1.installs }
            .prefix(limit)
            .map { item in
                SkillSummary(
                    id: SkillID(item.identifier),
                    name: item.name,
                    description: "",
                    source: SkillSourceReference(kind: .skillsSh, location: item.source, trusted: true),
                    installCount: item.installs,
                    tags: [],
                    lastUpdated: nil
                )
            }
    }

    /// Pulls every embedded skill object out of the RSC payload. Objects are flat (no nested
    /// braces) and carry the same keys as the search API, so each `{ … "skillId" … }` candidate
    /// is decoded independently; undecodable candidates are skipped.
    private static func extractSkills(from data: Data) -> [SkillsShSkill] {
        guard let payload = String(data: data, encoding: .utf8) else { return [] }

        let pattern = #"\{[^{}]*"skillId"[^{}]*\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(payload.startIndex..<payload.endIndex, in: payload)
        let decoder = JSONDecoder()

        return regex.matches(in: payload, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: payload),
                  let objectData = String(payload[matchRange]).data(using: .utf8)
            else { return nil }
            return try? decoder.decode(SkillsShSkill.self, from: objectData)
        }
    }
}

private struct SkillsShSkill: Decodable {
    let source: String
    let skillId: String
    let name: String
    let installs: Int

    var identifier: String { "\(source)/\(skillId)" }
}
