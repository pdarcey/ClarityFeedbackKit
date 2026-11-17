//
/* Project: ClarityFeedbackKit
   File: ClarityFeedbackTests
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation
import ClarityTesting
import Testing
@testable import ClarityFeedbackKit

@Suite("ClarityFeedback", .serialized)
struct ClarityFeedbackTests {
    private let relay = "https://relay.example.com/v1/feedback"

    @Test("configure stores the Info.plist token and the Secrets URL")
    func configureStoresBothValues() {
        #expect(ClarityFeedback.configure(appToken: "  a-token\n", ingestURL: { self.relay }))
        #expect(ClarityFeedback.isConfigured)
        #expect(ClarityFeedback.configuration?.appToken == "a-token")
        #expect(ClarityFeedback.configuration?.ingestURL.absoluteString == relay)
    }

    @Test(
        "configure stays unconfigured without a usable token",
        .clarity(255, "configure() nudged hosts to hardcode the token"),
        arguments: [nil, "", "   ", "$(CLARITY_FEEDBACK_APP_TOKEN)"] as [String?]
    )
    func configureRejectsMissingTokens(token: String?) {
        #expect(!ClarityFeedback.configure(appToken: token, ingestURL: { self.relay }))
        #expect(!ClarityFeedback.isConfigured)
    }

    @Test("configure stays unconfigured when the URL can't be read or isn't https")
    func configureRejectsBadURLs() {
        struct Unreadable: Error {}
        #expect(!ClarityFeedback.configure(appToken: "a-token", ingestURL: { throw Unreadable() }))
        #expect(!ClarityFeedback.configure(appToken: "a-token", ingestURL: { "http://relay.example.com/v1/feedback" }))
        #expect(!ClarityFeedback.isConfigured)
    }

    @Test("The obfuscated relay URL in Secrets decrypts to an https /v1/feedback endpoint")
    func secretsURLIsUsable() throws {
        let url = try #require(URL(string: try Secrets.ingestURL))
        #expect(url.scheme == "https")
        #expect(url.path == "/v1/feedback")
    }

    @Test("configure(bundle:) reads the token from the Info.plist key, and fails without it")
    func configureFromBundleWithoutTheKey() {
        // The test bundle has no ClarityFeedbackAppToken, like a build without the .xcconfig.
        #expect(!ClarityFeedback.configure(bundle: Bundle(for: BundleMarker.self)))
        #expect(ClarityFeedback.appTokenInfoPlistKey == "ClarityFeedbackAppToken")
    }

    @Test("Uses the real global ClarityFeedback.configuration by default")
    func defaultsToGlobalConfiguration() async throws {
        let relay = relay
        ClarityFeedback.configure(appToken: "test-ingest-token", ingestURL: { relay })
        let stub = StubURLRequestPerforming()
        let successBody = try JSONEncoder().encode(
            FeedbackSubmissionResponse(
                succeeded: true, url: "https://github.com/pdarcey/Clarity/issues/1", number: 1, error: nil
            )
        )
        let created = HTTPURLResponse(url: URL(string: relay)!, statusCode: 201, httpVersion: nil, headerFields: nil)!
        stub.result = .success((successBody, created))
        let client = FeedbackClient(session: stub)

        _ = try await client.submit(title: "Bug", body: "It broke")

        #expect(stub.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-ingest-token")
    }
}

/// A class in the test bundle, to find that bundle.
private final class BundleMarker {}
