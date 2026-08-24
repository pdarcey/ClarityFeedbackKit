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
    // `dismiss()` only closes a sheet/cover-style presentation. On macOS, host apps are
    // encouraged to present `ReportIssueView` in its own `Window` scene (a Mac-idiomatic
    // window, not a sheet) — closing that needs `dismissWindow()` instead, since `dismiss()`
    // has no effect on a `Window` scene's contents.
    #if os(macOS)
    @Environment(\.dismissWindow) private var dismissWindow
    #else
    @Environment(\.dismiss) private var dismiss
    #endif

    let submissionState: SubmissionState
    let isSubmitDisabled: Bool
    let submit: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if case .succeeded = submissionState {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: close)
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: close)
                    .disabled(submissionState == .submitting)
            }
            ToolbarItem(placement: .confirmationAction) {
                SubmitButton(state: submissionState, isDisabled: isSubmitDisabled, action: submit)
            }
        }
    }

    private func close() {
        #if os(macOS)
        dismissWindow()
        #else
        dismiss()
        #endif
    }
}
