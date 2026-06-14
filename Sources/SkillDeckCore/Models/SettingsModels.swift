import Foundation

public enum AppearanceMode: String, Codable, Sendable {
    case system
    case light
    case dark
}

public enum TelemetryConsentState: String, Codable, Sendable {
    case notAsked
    case declined
    case granted
}

public struct UserSettings: Hashable, Codable, Sendable {
    public var appearanceMode: AppearanceMode
    public var sentryConsent: TelemetryConsentState
    public var amplitudeConsent: TelemetryConsentState
    public var autoUpdateTrustedSources: Bool

    public init(
        appearanceMode: AppearanceMode = .system,
        sentryConsent: TelemetryConsentState = .notAsked,
        amplitudeConsent: TelemetryConsentState = .notAsked,
        autoUpdateTrustedSources: Bool = true
    ) {
        self.appearanceMode = appearanceMode
        self.sentryConsent = sentryConsent
        self.amplitudeConsent = amplitudeConsent
        self.autoUpdateTrustedSources = autoUpdateTrustedSources
    }
}
