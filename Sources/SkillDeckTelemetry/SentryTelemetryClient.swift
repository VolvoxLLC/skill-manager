import Foundation
import Sentry

public enum SentryTelemetryClient {
    public static func startIfConsented(dsn: String, consentGranted: Bool) {
        guard consentGranted else { return }
        SentrySDK.start { options in
            options.dsn = dsn
            options.sendDefaultPii = false
        }
    }
}
