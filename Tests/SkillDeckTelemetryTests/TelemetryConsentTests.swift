import XCTest
@testable import SkillDeckCore
@testable import SkillDeckTelemetry

final class TelemetryConsentTests: XCTestCase {
    func testNoEventsSentBeforeAmplitudeConsent() async {
        let sink = RecordingTelemetrySink()
        let client = ConsentGatedTelemetryClient(
            sink: sink,
            consent: TelemetryConsent(sentry: .declined, amplitude: .notAsked)
        )

        await client.track(.searchPerformed(queryLength: 6, resultCount: 2))

        let count = await sink.events.count
        XCTAssertEqual(count, 0)
    }

    func testEventSentAfterAmplitudeConsent() async {
        let sink = RecordingTelemetrySink()
        let client = ConsentGatedTelemetryClient(
            sink: sink,
            consent: TelemetryConsent(sentry: .declined, amplitude: .granted)
        )

        await client.track(.searchPerformed(queryLength: 6, resultCount: 2))

        let count = await sink.events.count
        XCTAssertEqual(count, 1)
    }
}
