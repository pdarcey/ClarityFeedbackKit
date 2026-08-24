//
/* Project: ClarityFeedbackKit
   File: FeedbackClientTests
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation
import Testing
@testable import ClarityFeedbackKit

/// A stub `URLRequestPerforming` that records the last request it received and returns a
/// scripted response — mirrors the same test-double shape Clarity's own
/// `GitHubIssueImporterTests` uses for the same seam.
final class StubURLRequestPerforming: URLRequestPerforming, @unchecked Sendable {
    var lastRequest: URLRequest?
    var result: Result<(Data, URLResponse), Error> = .failure(URLError(.unknown))

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return try result.get()
    }
}

@Suite("FeedbackClient")
struct FeedbackClientTests {
    private let testConfiguration = ClarityFeedback.Configuration(
        ingestURL: URL(string: "https://relay.example.com/v1/feedback")!,
        appToken: "test-ingest-token"
    )

    private func response(
        status: Int,
        url: URL = URL(string: "https://relay.example.com/v1/feedback")!
    ) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    @Test("Throws notConfigured when no configuration is available")
    func throwsWhenNotConfigured() async {
        let stub = StubURLRequestPerforming()
        let client = FeedbackClient(session: stub, configurationProvider: { nil })

        await #expect(throws: FeedbackClient.SubmissionError.notConfigured) {
            _ = try await client.submit(title: "Bug", body: "It broke")
        }
    }

    @Test("Sends the configured URL, Bearer token, and encoded fields")
    func sendsCorrectRequest() async throws {
        let stub = StubURLRequestPerforming()
        let successBody = try JSONEncoder().encode(
            FeedbackSubmissionResponse(
                succeeded: true, url: "https://github.com/pdarcey/Clarity/issues/1", number: 1, error: nil
            )
        )
        stub.result = .success((successBody, response(status: 201)))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        _ = try await client.submit(title: "Crashes on launch", body: "Steps...")

        let sentRequest = try #require(stub.lastRequest)
        #expect(sentRequest.url == testConfiguration.ingestURL)
        #expect(sentRequest.httpMethod == "POST")
        #expect(sentRequest.value(forHTTPHeaderField: "Authorization") == "Bearer test-ingest-token")
        #expect(sentRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let sentBody = try #require(sentRequest.httpBody)
        let decoded = try JSONDecoder().decode(FeedbackSubmission.self, from: sentBody)
        #expect(decoded.title == "Crashes on launch")
        #expect(decoded.body == "Steps...")
        #expect(decoded.osVersion == DeviceInfo.osVersion)
        #expect(decoded.deviceModel == DeviceInfo.deviceModel)
    }

    @Test("Returns the created issue's URL on a 201 success")
    func returnsURLOnSuccess() async throws {
        let stub = StubURLRequestPerforming()
        let successBody = try JSONEncoder().encode(
            FeedbackSubmissionResponse(
                succeeded: true, url: "https://github.com/pdarcey/Clarity/issues/42", number: 42, error: nil
            )
        )
        stub.result = .success((successBody, response(status: 201)))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        let url = try await client.submit(title: "Bug", body: "It broke")

        #expect(url == URL(string: "https://github.com/pdarcey/Clarity/issues/42"))
    }

    @Test("Throws .server with the relay's error message on a non-201 response")
    func throwsServerErrorOnRejection() async throws {
        let stub = StubURLRequestPerforming()
        let errorBody = try JSONEncoder().encode(
            FeedbackSubmissionResponse(succeeded: false, url: nil, number: nil, error: "Invalid ingest token.")
        )
        stub.result = .success((errorBody, response(status: 401)))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        await #expect(throws: FeedbackClient.SubmissionError.server("Invalid ingest token.")) {
            _ = try await client.submit(title: "Bug", body: "It broke")
        }
    }

    @Test("Throws .network when the underlying request fails")
    func throwsNetworkErrorOnTransportFailure() async {
        let stub = StubURLRequestPerforming()
        stub.result = .failure(URLError(.notConnectedToInternet))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        await #expect(throws: FeedbackClient.SubmissionError.self) {
            _ = try await client.submit(title: "Bug", body: "It broke")
        }
    }

    @Test("Throws .server when the response body isn't the expected shape")
    func throwsServerErrorOnMalformedResponse() async {
        let stub = StubURLRequestPerforming()
        stub.result = .success((Data("not json".utf8), response(status: 500)))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        await #expect(throws: FeedbackClient.SubmissionError.self) {
            _ = try await client.submit(title: "Bug", body: "It broke")
        }
    }

    @Test("Uses the real global ClarityFeedback.configuration by default")
    func defaultsToGlobalConfiguration() async throws {
        ClarityFeedback.configure(ingestURL: testConfiguration.ingestURL, appToken: testConfiguration.appToken)
        let stub = StubURLRequestPerforming()
        let successBody = try JSONEncoder().encode(
            FeedbackSubmissionResponse(
                succeeded: true, url: "https://github.com/pdarcey/Clarity/issues/1", number: 1, error: nil
            )
        )
        stub.result = .success((successBody, response(status: 201)))
        let client = FeedbackClient(session: stub)

        _ = try await client.submit(title: "Bug", body: "It broke")

        #expect(stub.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-ingest-token")
    }
}
