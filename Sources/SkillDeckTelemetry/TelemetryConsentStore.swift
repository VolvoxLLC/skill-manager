import Foundation
import SkillDeckCore

public struct TelemetryConsentStore: Sendable {
    public private(set) var consent: TelemetryConsent

    public init(consent: TelemetryConsent = TelemetryConsent(sentry: .notAsked, amplitude: .notAsked)) {
        self.consent = consent
    }
}
