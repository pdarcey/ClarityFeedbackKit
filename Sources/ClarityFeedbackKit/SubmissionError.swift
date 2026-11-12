//
/* Project: ClarityFeedbackKit
   File: SubmissionError
   Created by Paul Darcey on 12/11/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation

/// Why a submission failed. The associated values are diagnostics for logs and tests; what
/// the user sees (`errorDescription`) is one of a few fixed messages, so nothing the relay
/// or the network says — which could name the GitHub repo, or the relay's URL — reaches
/// them (#680).
enum SubmissionError: Error, LocalizedError, Sendable, Equatable {
    /// ``ClarityFeedback/configure(bundle:)`` hasn't succeeded.
    case notConfigured
    /// The request couldn't be built.
    case encoding(String)
    /// The request didn't get a response: the underlying error's description.
    case network(String)
    /// The relay answered with something other than success: its status, and its
    /// `error` text or a description of the unexpected body.
    case server(status: Int, detail: String)
    /// The relay answered with a redirect, which is refused (#679).
    case redirected(status: Int, location: String?)

    /// Shown when the request never got a response.
    static let connectionMessage = "Couldn’t send your report. Check your connection and try again."
    /// Shown for any failure the user can't fix themselves.
    static let serviceMessage = "The feedback service couldn’t accept your report right now. Try again later."
    /// Shown when the host app hasn't configured the SDK.
    static let notConfiguredMessage = "Feedback isn’t set up in this app."

    /// The fixed, user-facing message for this failure.
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            Self.notConfiguredMessage
        case .network:
            Self.connectionMessage
        case .encoding, .server, .redirected:
            Self.serviceMessage
        }
    }
}
