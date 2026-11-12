//
/* Project: ClarityFeedbackKit
   File: NoRedirectSession
   Created by Paul Darcey on 12/11/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation

/// `FeedbackClient`'s real network path: `URLSession.shared`, with every redirect refused
/// by ``NoRedirectDelegate`` (#679).
struct NoRedirectSession: URLRequestPerforming {
    /// The session the requests go through.
    let session: URLSession

    /// Creates the network path over `session` (the shared session by default).
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Performs the request, refusing redirects.
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request, delegate: NoRedirectDelegate())
    }
}
