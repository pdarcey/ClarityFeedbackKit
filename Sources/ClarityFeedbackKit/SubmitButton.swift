//
/* Project: ClarityFeedbackKit
   File: SubmitButton
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import SwiftUI

/// ``ReportIssueView``'s confirmation-action toolbar content: a `Button` while idle or
/// after a failed attempt, a spinner while a submission is in flight.
struct SubmitButton: View {
    let state: SubmissionState
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        if state == .submitting {
            ProgressView()
        } else {
            Button("Submit", action: action)
                .disabled(isDisabled)
        }
    }
}
