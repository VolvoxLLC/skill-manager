import Foundation
import SkillDeckCore

public enum TelemetryEvent: Equatable, Sendable {
    case appLaunched
    case searchPerformed(queryLength: Int, resultCount: Int)
    case skillDetailOpened(sourceKind: SkillSourceKind)
    case skillInstalled(sourceKind: SkillSourceKind)
    case updateChecked(resultCount: Int)
    case skillUpdated(sourceKind: SkillSourceKind)
    case sourceAdded(sourceKind: SkillSourceKind)
    case errorOccurred(code: String)
}

public struct TelemetryConsent: Sendable {
    public var sentry: TelemetryConsentState
    public var amplitude: TelemetryConsentState

    public init(sentry: TelemetryConsentState, amplitude: TelemetryConsentState) {
        self.sentry = sentry
        self.amplitude = amplitude
    }
}

public protocol TelemetrySink: Sendable {
    func track(_ event: TelemetryEvent) async
}

public final actor RecordingTelemetrySink: TelemetrySink {
    public private(set) var events: [TelemetryEvent] = []

    public init() {}

    public func track(_ event: TelemetryEvent) async {
        events.append(event)
    }
}

public struct ConsentGatedTelemetryClient: Sendable {
    private let sink: TelemetrySink
    private let consent: TelemetryConsent

    public init(sink: TelemetrySink, consent: TelemetryConsent) {
        self.sink = sink
        self.consent = consent
    }

    public func track(_ event: TelemetryEvent) async {
        guard consent.amplitude == .granted else { return }
        await sink.track(event)
    }
}
