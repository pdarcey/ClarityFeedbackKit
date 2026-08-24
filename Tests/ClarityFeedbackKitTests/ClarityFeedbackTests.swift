//
/* Project: ClarityFeedbackKit
   File: ClarityFeedbackTests
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation
import Testing
@testable import ClarityFeedbackKit

@Suite("ClarityFeedback", .serialized)
struct ClarityFeedbackTests {
    @Test("isConfigured reflects whether configure(...) has been called")
    func isConfiguredReflectsConfigure() {
        ClarityFeedback.configure(
            ingestURL: URL(string: "https://relay.example.com/v1/feedback")!,
            appToken: "a-token"
        )

        #expect(ClarityFeedback.isConfigured)
        #expect(ClarityFeedback.configuration?.appToken == "a-token")
    }
}
