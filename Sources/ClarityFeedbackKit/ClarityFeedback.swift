//
/* Project: ClarityFeedbackKit
   File: ClarityFeedback
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation
import OSLog
import Synchronization

private let logger = Logger(subsystem: "com.xerodonia.ClarityFeedbackKit", category: "ClarityFeedback")

/// The SDK's single configuration point. Call ``configure(bundle:)`` once, early in app
/// launch, before presenting ``ReportIssueView``.
///
/// Nothing secret is passed in code (#255, 2.0.0):
/// - the relay's endpoint comes from the package's obfuscated `Secrets.ingestURL`;
/// - this app's ingest token comes from the host app's Info.plist key
///   `ClarityFeedbackAppToken`, which references a build setting set in an `.xcconfig`
///   that isn't committed (see the Readme's "Setting up the ingest token").
///
/// The token is an opaque per-app ingest token issued by the relay (see the
/// `clarity-feedback-relay` repo), never a raw GitHub credential: it only ever authorizes
/// creating issues on one repository, and can be revoked independently of every other app.
///
/// Storage is a `Mutex`, not a `@MainActor`-isolated property, so `configure()` can be
/// called synchronously from anywhere — including a SwiftUI `App`'s `init()`, which isn't
/// itself main-actor-isolated — without forcing callers onto the main actor first.
public enum ClarityFeedback {
    /// The Info.plist key that holds this app's ingest token.
    public static let appTokenInfoPlistKey = "ClarityFeedbackAppToken"

    /// One app's relay endpoint + ingest token. Not exposed publicly — callers only ever
    /// set this via ``configure(bundle:)`` and never read it back directly.
    struct Configuration: Sendable {
        let ingestURL: URL
        let appToken: String
    }

    private static let storage = Mutex<Configuration?>(nil)

    /// Configures the SDK from the relay URL in `Secrets` and the ingest token in the app's
    /// Info.plist. Call once, as early as practical in app launch.
    ///
    /// If the token is missing (for example, a build without the `.xcconfig`), feedback stays
    /// unconfigured and a warning is logged, rather than crashing. Check ``isConfigured`` to
    /// decide whether to show your "Report a Bug" entry point.
    /// - Parameter bundle: The bundle whose Info.plist holds the token. Defaults to the app's.
    /// - Returns: `true` if the SDK is now configured.
    @discardableResult
    public static func configure(bundle: Bundle = .main) -> Bool {
        configure(
            appToken: bundle.object(forInfoDictionaryKey: appTokenInfoPlistKey) as? String,
            ingestURL: { try Secrets.ingestURL }
        )
    }

    /// The testable core of ``configure(bundle:)``: validates both values, then stores them.
    /// - Parameters:
    ///   - appToken: The Info.plist value, if any.
    ///   - ingestURL: Reads the relay's endpoint (`Secrets.ingestURL` in the app).
    /// - Returns: `true` if both values were usable and are now stored.
    @discardableResult
    static func configure(appToken: String?, ingestURL: () throws -> String) -> Bool {
        guard let token = usableToken(appToken) else {
            logger.warning(
                """
                ClarityFeedbackKit isn't configured: the Info.plist key \(appTokenInfoPlistKey, privacy: .public) \
                is missing or empty. Set it from an .xcconfig (see the Readme).
                """
            )
            storage.withLock { $0 = nil }
            return false
        }
        let url: URL
        do {
            guard let parsed = URL(string: try ingestURL()), parsed.scheme == "https" else {
                logger.error("ClarityFeedbackKit isn't configured: Secrets.ingestURL isn't an https URL.")
                storage.withLock { $0 = nil }
                return false
            }
            url = parsed
        } catch {
            logger.error(
                "ClarityFeedbackKit isn't configured: couldn't read Secrets.ingestURL (\(error, privacy: .public))."
            )
            storage.withLock { $0 = nil }
            return false
        }
        storage.withLock { $0 = Configuration(ingestURL: url, appToken: token) }
        return true
    }

    /// The token, trimmed, or `nil` when it's empty or an unexpanded build setting such as
    /// `$(CLARITY_FEEDBACK_APP_TOKEN)`.
    static func usableToken(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            return nil
        }
        return trimmed
    }

    /// `true` once ``configure(bundle:)`` has succeeded. `ReportIssueView` doesn't check
    /// this itself — a submission before configuration fails with a short "isn't set up"
    /// message — so host apps should use it to decide whether to show the entry point at all.
    public static var isConfigured: Bool {
        configuration != nil
    }

    static var configuration: Configuration? {
        storage.withLock { $0 }
    }
}
