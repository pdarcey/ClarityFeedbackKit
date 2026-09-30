//
/* Project: ClarityFeedbackKit
   File: SubmissionState
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation

/// Tracks ``ReportIssueView``'s submission lifecycle.
enum SubmissionState: Equatable, Sendable {
    case idle
    case submitting
    case succeeded
    case failed(String)
}
