//
/* Project: ClarityFeedbackKit
   File: FeedbackSubmission
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation

/// Request body sent to the relay's `POST /v1/feedback`. Field names and shape must stay
/// in sync with `clarity-feedback-relay`'s `FeedbackPayload` interface. `Decodable` is only
/// needed by tests (to verify what `FeedbackClient` actually sent) — production code only
/// ever encodes this.
struct FeedbackSubmission: Codable, Sendable {
    let title: String
    let body: String
    let appVersion: String?
    let osVersion: String?
    let deviceModel: String?
}

/// Response body from the relay. Mirrors `clarity-feedback-relay`'s `jsonError`/success
/// shapes: `ok: true` responses carry `url`/`number`; `ok: false` responses carry `error`.
/// `Encodable` is only needed by tests (to build scripted response bodies) — production
/// code only ever decodes this.
struct FeedbackSubmissionResponse: Codable, Sendable {
    let succeeded: Bool
    let url: String?
    let number: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case succeeded = "ok"
        case url, number, error
    }
}
