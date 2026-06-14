import AmplitudeSwift
import Foundation

public final class AmplitudeTelemetryClient: TelemetrySink, @unchecked Sendable {
    private let amplitude: Amplitude

    public init(apiKey: String) {
        amplitude = Amplitude(configuration: Configuration(apiKey: apiKey))
    }

    public func track(_ event: TelemetryEvent) async {
        amplitude.track(eventType: String(describing: event))
    }
}
