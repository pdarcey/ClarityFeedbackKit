//
/* Project: ClarityFeedbackKit
   File: ReportIssueView
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.xerodonia.ClarityFeedbackKit", category: "ReportIssueView")

/// A ready-made "Report a Bug" form. It handles submission, in-flight state, and
/// success/error feedback itself. On iOS and iPadOS present it as a sheet; on macOS give it
/// its own `Window` scene (see the Readme), because it closes itself with `dismissWindow()`
/// there (#257). Call ``ClarityFeedback/configure(bundle:)`` once, earlier in app launch,
/// and only offer this when ``ClarityFeedback/isConfigured`` is `true`.
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
                .navigationTitle(submissionState == .succeeded ? "Feedback sent" : "Send feedback")
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
                // The created issue's URL is for the developer, not the reporter — log it
                // for diagnostics rather than surfacing it in the UI.
                let url = try await FeedbackClient().submit(title: title, body: description)
                logger.info("Feedback submitted as \(url.absoluteString)")
                submissionState = .succeeded
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
