//
/* Project: ClarityFeedbackKit
   File: FeedbackClient
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.xerodonia.ClarityFeedbackKit", category: "FeedbackClient")

/// Posts a feedback submission to the configured relay. Internal — ``ReportIssueView`` is
/// the SDK's public surface; host apps don't need to touch this directly.
///
/// `session` and `configurationProvider` are both injectable (defaulting to the real
/// `NoRedirectSession` / `ClarityFeedback.configuration`) so tests can exercise request
/// construction and response handling without a real network call or touching the shared
/// global configuration — the same dependency-injection-for-testability shape Clarity's
/// own `Database.importGitHubIssues(for:importer:tokenProvider:)` uses.
struct FeedbackClient: Sendable {
    private let session: any URLRequestPerforming
    private let configurationProvider: @Sendable () -> ClarityFeedback.Configuration?

    init(
        session: any URLRequestPerforming = NoRedirectSession(),
        configurationProvider: @escaping @Sendable () -> ClarityFeedback.Configuration? = {
            ClarityFeedback.configuration
        }
    ) {
        self.session = session
        self.configurationProvider = configurationProvider
    }

    /// `true` when requests go through the redirect-refusing ``NoRedirectSession`` (#679).
    var usesNoRedirectSession: Bool {
        session is NoRedirectSession
    }

    /// Submits a report. Returns the created GitHub issue's URL on success.
    func submit(title: String, body: String) async throws(SubmissionError) -> URL {
        guard let configuration = configurationProvider() else {
            logger.error("Feedback submitted before ClarityFeedback.configure() succeeded.")
            throw .notConfigured
        }

        let submission = FeedbackSubmission(
            title: title,
            body: body,
            appVersion: DeviceInfo.appVersion,
            osVersion: DeviceInfo.osVersion,
            deviceModel: DeviceInfo.deviceModel
        )

        var request = URLRequest(url: configuration.ingestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.appToken)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONEncoder().encode(submission)
        } catch {
            logger.error("Couldn't encode the submission: \(error.localizedDescription, privacy: .public)")
            throw .encoding(error.localizedDescription)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Feedback submission network error: \(error.localizedDescription, privacy: .public)")
            throw .network(error.localizedDescription)
        }
        return try issueURL(from: data, response: response)
    }

    /// Reads the relay's answer: the created issue's URL, or the reason it failed.
    /// - Parameters:
    ///   - data: The response body.
    ///   - response: The response, which should be HTTP.
    private func issueURL(from data: Data, response: URLResponse) throws(SubmissionError) -> URL {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Feedback submission got a response that isn't HTTP.")
            throw .network("Unexpected response type.")
        }

        if (300..<400).contains(httpResponse.statusCode) {
            let location = httpResponse.value(forHTTPHeaderField: "Location")
            let target = location ?? "nowhere"
            logger.error(
                "The relay redirected (HTTP \(httpResponse.statusCode)) to \(target, privacy: .public); not followed."
            )
            throw .redirected(status: httpResponse.statusCode, location: location)
        }

        guard let decoded = try? JSONDecoder().decode(FeedbackSubmissionResponse.self, from: data) else {
            logger.error("Unexpected response from the relay (HTTP \(httpResponse.statusCode)).")
            throw .server(status: httpResponse.statusCode, detail: "Unexpected response body.")
        }

        guard httpResponse.statusCode == 201, decoded.succeeded,
              let urlString = decoded.url, let url = URL(string: urlString) else {
            let detail = decoded.error ?? "Rejected without a message."
            logger.warning(
                "Feedback submission rejected (HTTP \(httpResponse.statusCode)): \(detail, privacy: .public)"
            )
            throw .server(status: httpResponse.statusCode, detail: detail)
        }

        return url
    }
}
