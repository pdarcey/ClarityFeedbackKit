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
            Section("Describe the issue") {
                TextField("Title", text: $title)
                // A bare TextEditor has no border or background of its own, so its edges
                // are effectively invisible inside a Form — especially in dark mode on
                // macOS. Give it a visible container so it reads as an editable field.
                TextEditor(text: $description)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(.thinMaterial, in: .rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.3))
                    }
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
        .padding()
    }
}
