//
/* Project: ClarityFeedbackKit
   File: NoRedirectDelegate
   Created by Paul Darcey on 12/11/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation

/// Refuses every HTTP redirect, so a submission (with its `Authorization: Bearer` token and
/// the user's text) is only ever sent to the configured relay (#679). The relay never
/// redirects; when a redirect is refused, the 3xx response itself comes back and
/// `FeedbackClient` treats it as a failure.
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    /// Returns `nil`, which tells `URLSession` not to follow the redirect.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
