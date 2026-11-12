//
/* Project: ClarityFeedbackKit
   File: URLRequestPerforming
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation

/// A seam over `URLSession.data(for:)` so `FeedbackClient` can be tested with a stub
/// instead of a real network call. Mirrors the same pattern used by Clarity's own
/// `GitHubIssueImporter` for the same reason.
protocol URLRequestPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}
