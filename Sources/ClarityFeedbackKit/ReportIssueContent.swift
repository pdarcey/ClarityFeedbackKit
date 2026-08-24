//
/* Project: ClarityFeedbackKit
   File: ReportIssueContent
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import SwiftUI

/// ``ReportIssueView``'s body content: the editable ``ReportForm`` while idle/submitting/
/// failed, or ``SubmissionSuccessView`` once a submission has succeeded.
struct ReportIssueContent: View {
    @Binding var title: String
    @Binding var description: String
    let submissionState: SubmissionState

    var body: some View {
        if case .succeeded(let url) = submissionState {
            SubmissionSuccessView(url: url)
        } else {
            ReportForm(title: $title, description: $description, submissionState: submissionState)
        }
    }
}
