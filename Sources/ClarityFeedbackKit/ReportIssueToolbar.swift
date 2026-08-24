//
/* Project: ClarityFeedbackKit
   File: ReportIssueToolbar
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import SwiftUI

/// ``ReportIssueView``'s toolbar: Cancel/Submit while editing, a single Done button once
/// a submission has succeeded.
struct ReportIssueToolbar: ToolbarContent {
    @Environment(\.dismiss) private var dismiss

    let submissionState: SubmissionState
    let isSubmitDisabled: Bool
    let submit: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if case .succeeded = submissionState {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(submissionState == .submitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                SubmitButton(state: submissionState, isDisabled: isSubmitDisabled, action: submit)
            }
        }
    }
}
