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
/// `URLSession.shared` / `ClarityFeedback.configuration`) so tests can exercise request
/// construction and response handling without a real network call or touching the shared
/// global configuration — the same dependency-injection-for-testability shape Clarity's
/// own `Database.importGitHubIssues(for:importer:tokenProvider:)` uses.
struct FeedbackClient: Sendable {
    enum SubmissionError: Error, LocalizedError, Sendable, Equatable {
        case notConfigured
        case network(String)
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "ClarityFeedback.configure(ingestURL:appToken:) hasn't been called yet."
            case .network(let message):
                return "Couldn't reach the feedback server: \(message)"
            case .server(let message):
                return message
            }
        }
    }

    private let session: any URLRequestPerforming
    private let configurationProvider: @Sendable () -> ClarityFeedback.Configuration?

    init(
        session: any URLRequestPerforming = URLSession.shared,
        configurationProvider: @escaping @Sendable () -> ClarityFeedback.Configuration? = {
            ClarityFeedback.configuration
        }
    ) {
        self.session = session
        self.configurationProvider = configurationProvider
    }

    /// Submits a report. Returns the created GitHub issue's URL on success.
    func submit(title: String, body: String) async throws(SubmissionError) -> URL {
        guard let configuration = configurationProvider() else {
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
            throw .network("Couldn't encode the submission: \(error.localizedDescription)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Feedback submission network error: \(error.localizedDescription)")
            throw .network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw .network("Unexpected response type.")
        }

        guard let decoded = try? JSONDecoder().decode(FeedbackSubmissionResponse.self, from: data) else {
            throw .server("Unexpected response from the server (HTTP \(httpResponse.statusCode)).")
        }

        guard httpResponse.statusCode == 201, decoded.succeeded,
              let urlString = decoded.url, let url = URL(string: urlString) else {
            let message = decoded.error ?? "The server rejected the submission (HTTP \(httpResponse.statusCode))."
            logger.warning("Feedback submission rejected: \(message)")
            throw .server(message)
        }

        return url
    }
}
