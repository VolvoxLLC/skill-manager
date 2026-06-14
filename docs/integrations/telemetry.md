# Telemetry

SkillDeck wires Sentry (crash reporting) and Amplitude (analytics) through Swift Package
Manager but keeps both disabled until the user grants explicit, separate consent.

## Defaults

- Sentry crash reporting: off until consent.
- Amplitude analytics: off until consent.
- Skill contents: never sent.
- Raw local file paths: never sent.
- Private repository URLs: never sent.
- Public source URLs: redacted or normalized where possible.

## Design

- `ConsentGatedTelemetryClient` drops every event unless Amplitude consent is `granted`.
- `SentryTelemetryClient.startIfConsented` is a no-op unless Sentry consent is granted.
- No SwiftUI view calls Sentry or Amplitude directly; both sit behind app-owned types.
- In-app log messages run through path redaction before display or export.

`TelemetryConsentTests` asserts that no event reaches a telemetry sink before consent.

## Tracked events

App launched, search performed, skill detail opened, skill installed, update checked,
skill updated, source added, error occurred. Events carry only coarse, non-identifying
fields (e.g. query length and result counts), never raw input.
