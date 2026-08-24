//
/* Project: ClarityFeedbackKit
   File: ReportForm
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import SwiftUI

/// ``ReportIssueView``'s editable form: title, description, the automatic metadata
/// footer, and an inline error message after a failed submission attempt.
struct ReportForm: View {
    @Binding var title: String
    @Binding var description: String
    let submissionState: SubmissionState

    var body: some View {
        Form {
            Section("Report a Bug or Idea") {
                TextField("Title", text: $title)
                TextEditor(text: $description)
                    .frame(minHeight: 120)
            }
            Section("Included automatically") {
                FeedbackMetadataFooter()
            }
            if case .failed(let message) = submissionState {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
        .disabled(submissionState == .submitting)
    }
}
