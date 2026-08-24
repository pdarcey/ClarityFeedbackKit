//
/* Project: ClarityFeedbackKit
   File: ClarityFeedback
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation
import Synchronization

/// The SDK's single configuration point. Call ``configure(ingestURL:appToken:)`` once,
/// early in app launch — before presenting ``ReportIssueView`` — to tell the SDK where to
/// send feedback and which app it's reporting on behalf of.
///
/// Mirrors the "configure once with a token" shape of telemetry SDKs like Sentry/PostHog:
/// `appToken` is an opaque per-app ingest token issued by the relay (see the
/// `clarity-feedback-relay` repo), never a raw GitHub credential — the token only ever
/// authorizes creating issues on one specific repository, and can be revoked independently
/// of every other app using the same relay.
///
/// Storage is a `Mutex`, not a `@MainActor`-isolated property, so `configure(...)` can be
/// called synchronously from anywhere — including a SwiftUI `App`'s `init()`, which isn't
/// itself main-actor-isolated — without forcing callers onto the main actor first.
public enum ClarityFeedback {
    /// One app's relay endpoint + ingest token. Not exposed publicly — callers only ever
    /// set this via ``configure(ingestURL:appToken:)`` and never read it back directly.
    struct Configuration: Sendable {
        let ingestURL: URL
        let appToken: String
    }

    private static let storage = Mutex<Configuration?>(nil)

    /// Configures the SDK. Call once, as early as practical in app launch.
    /// - Parameters:
    ///   - ingestURL: The relay's feedback endpoint, e.g.
    ///     `https://clarity-feedback-relay.<your-subdomain>.workers.dev/v1/feedback`.
    ///   - appToken: This app's ingest token, issued once per app by whoever runs the relay.
    public static func configure(ingestURL: URL, appToken: String) {
        storage.withLock { $0 = Configuration(ingestURL: ingestURL, appToken: appToken) }
    }

    /// `true` once ``configure(ingestURL:appToken:)`` has been called. `ReportIssueView`
    /// doesn't check this itself — a submission attempt before configuration simply fails
    /// with `FeedbackClient.SubmissionError.notConfigured` — but host apps can use this to
    /// decide whether to show the report-a-bug entry point at all.
    public static var isConfigured: Bool {
        configuration != nil
    }

    static var configuration: Configuration? {
        storage.withLock { $0 }
    }
}
