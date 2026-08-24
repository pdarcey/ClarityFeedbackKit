//
/* Project: ClarityFeedbackKit
   File: ReportIssueView
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import SwiftUI

/// A ready-made "Report a Bug" form. Present it as a sheet from your app's UI — it handles
/// submission, in-flight state, and success/error feedback itself. Call
/// ``ClarityFeedback/configure(ingestURL:appToken:)`` once, earlier in app launch, before
/// presenting this.
///
/// v1 is text-only: title + description, plus an automatic app/OS/device metadata footer.
/// There's no screenshot/attachment support yet — GitHub's Issues REST API has no
/// first-party attachment endpoint, so that needs blob storage on the relay, which is a
/// deliberate fast-follow rather than a v1 requirement.
public struct ReportIssueView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var submissionState: SubmissionState = .idle

    public init() {}

    public var body: some View {
        NavigationStack {
            ReportIssueContent(title: $title, description: $description, submissionState: submissionState)
                .navigationTitle("Report a Bug")
                .toolbar {
                    ReportIssueToolbar(
                        submissionState: submissionState,
                        isSubmitDisabled: isSubmitDisabled,
                        submit: submit
                    )
                }
        }
    }

    private var isSubmitDisabled: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        submissionState = .submitting
        Task {
            do {
                let url = try await FeedbackClient().submit(title: title, body: description)
                submissionState = .succeeded(url)
            } catch {
                submissionState = .failed(error.localizedDescription)
            }
        }
    }
}

#if DEBUG
#Preview {
    ReportIssueView()
}
#endif
