//
/* Project: ClarityFeedbackKit
   File: FeedbackClientTests
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation
import ClarityTesting
import Testing
@testable import ClarityFeedbackKit

/// A stub `URLRequestPerforming` that records the last request it received and returns a
/// scripted response — mirrors the same test-double shape Clarity's own
/// `GitHubIssueImporterTests` uses for the same seam.
final class StubURLRequestPerforming: URLRequestPerforming, @unchecked Sendable {
    var lastRequest: URLRequest?
    var requestCount = 0
    var result: Result<(Data, URLResponse), Error> = .failure(URLError(.unknown))

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        requestCount += 1
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

        await #expect(throws: SubmissionError.notConfigured) {
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

    @Test("Throws .server with the relay's status and message on a non-201 response")
    func throwsServerErrorOnRejection() async throws {
        let stub = StubURLRequestPerforming()
        let errorBody = try JSONEncoder().encode(
            FeedbackSubmissionResponse(succeeded: false, url: nil, number: nil, error: "Invalid ingest token.")
        )
        stub.result = .success((errorBody, response(status: 401)))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        await #expect(throws: SubmissionError.server(status: 401, detail: "Invalid ingest token.")) {
            _ = try await client.submit(title: "Bug", body: "It broke")
        }
    }

    @Test("Throws .network when the underlying request fails")
    func throwsNetworkErrorOnTransportFailure() async {
        let stub = StubURLRequestPerforming()
        stub.result = .failure(URLError(.notConnectedToInternet))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        await #expect(throws: SubmissionError.network(URLError(.notConnectedToInternet).localizedDescription)) {
            _ = try await client.submit(title: "Bug", body: "It broke")
        }
    }

    @Test("Throws .server when the response body isn't the expected shape")
    func throwsServerErrorOnMalformedResponse() async {
        let stub = StubURLRequestPerforming()
        stub.result = .success((Data("not json".utf8), response(status: 500)))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        await #expect(throws: SubmissionError.server(status: 500, detail: "Unexpected response body.")) {
            _ = try await client.submit(title: "Bug", body: "It broke")
        }
    }

    @Test(
        "Refuses a redirect: fails, with no second request",
        .clarity(679, "Redirects could forward the token and report")
    )
    func refusesRedirects() async {
        let stub = StubURLRequestPerforming()
        let redirect = HTTPURLResponse(
            url: testConfiguration.ingestURL, statusCode: 307, httpVersion: nil,
            headerFields: ["Location": "https://elsewhere.example.com/collect"]
        )!
        stub.result = .success((Data(), redirect))
        let client = FeedbackClient(session: stub, configurationProvider: { self.testConfiguration })

        let expected = SubmissionError.redirected(status: 307, location: "https://elsewhere.example.com/collect")
        await #expect(throws: expected) {
            _ = try await client.submit(title: "Bug", body: "It broke")
        }
        #expect(stub.requestCount == 1)
    }

    @Test(
        "The real network path refuses redirects",
        .clarity(679, "Redirects could forward the token and report")
    )
    func realSessionRefusesRedirects() async {
        let delegate = NoRedirectDelegate()
        let request = URLRequest(url: URL(string: "https://elsewhere.example.com")!)
        let response = HTTPURLResponse(
            url: testConfiguration.ingestURL, statusCode: 307, httpVersion: nil, headerFields: nil
        )!
        let task = URLSession.shared.dataTask(with: request)
        let next = await delegate.urlSession(
            .shared, task: task, willPerformHTTPRedirection: response, newRequest: request
        )
        #expect(next == nil)
        #expect(FeedbackClient().usesNoRedirectSession)
    }

    @Test(
        "Users only ever see a fixed message, never the relay's or the network's text",
        .clarity(680, "Relay and network error text shown to users"),
        arguments: [
            SubmissionError.server(status: 502, detail: "GitHub rejected the issue: Not Found pdarcey/SecretRepo"),
            .server(status: 429, detail: "Rate limit exceeded. Try again shortly."),
            .redirected(status: 307, location: "https://elsewhere.example.com"),
            .encoding("bad data"),
            .network("Could not connect to https://relay.example.com/v1/feedback")
        ]
    )
    func userMessagesAreFixed(error: SubmissionError) throws {
        let message = try #require(error.errorDescription)
        #expect([SubmissionError.serviceMessage, SubmissionError.connectionMessage].contains(message))
        #expect(!message.contains("GitHub"))
        #expect(!message.contains("relay.example.com"))
    }

    @Test(
        "A rate limit (429) gets the same message as any other relay failure",
        .clarity(680, "Relay and network error text shown to users")
    )
    func rateLimitMessageIsTheServiceMessage() {
        #expect(SubmissionError.server(status: 429, detail: "x").errorDescription == SubmissionError.serviceMessage)
        #expect(SubmissionError.notConfigured.errorDescription == SubmissionError.notConfiguredMessage)
    }
}
