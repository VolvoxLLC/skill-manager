import Foundation

/// Persists and resolves a security-scoped bookmark, letting a sandboxed app
/// retain read access to a user-selected directory across launches.
///
/// The sandbox grants access only to URLs the user explicitly selects (via an
/// open panel). Storing a security-scoped bookmark — enabled by the
/// `com.apple.security.files.bookmarks.app-scope` entitlement — lets that grant
/// survive relaunches without re-prompting.
public final class SecurityScopedBookmarkStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    /// - Parameters:
    ///   - defaults: Backing store for the bookmark data. Defaults to `.standard`.
    ///   - key: Defaults key under which the bookmark is stored.
    public init(defaults: UserDefaults = .standard, key: String = "installedSkillsHomeBookmark") {
        self.defaults = defaults
        self.key = key
    }

    /// Whether a bookmark has been persisted.
    public var hasBookmark: Bool {
        defaults.data(forKey: key) != nil
    }

    /// Creates and stores a security-scoped bookmark for a user-selected URL.
    /// - Parameter url: A URL obtained from an open panel (powerbox-granted).
    /// - Throws: An error if the bookmark cannot be created.
    public func save(url: URL) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: key)
    }

    /// Resolves the stored bookmark to a URL, refreshing it transparently if stale.
    /// - Returns: The resolved URL, or `nil` if no bookmark is stored.
    /// - Throws: An error if a stored bookmark cannot be resolved.
    public func resolveURL() throws -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try save(url: url)
        }

        return url
    }

    /// Removes the stored bookmark, forcing the next access to re-prompt.
    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
