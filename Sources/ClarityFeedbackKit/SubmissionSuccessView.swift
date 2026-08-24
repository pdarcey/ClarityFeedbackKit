//
/* Project: ClarityFeedbackKit
   File: SubmissionSuccessView
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import SwiftUI

/// Shown in place of the report form once a submission succeeds — confirms it worked and
/// links straight to the created GitHub issue.
struct SubmissionSuccessView: View {
    let url: URL

    var body: some View {
        ContentUnavailableView {
            Label("Thanks for the report!", systemImage: "checkmark.circle")
        } description: {
            Text("Your report has been sent.")
        } actions: {
            Link("View on GitHub", destination: url)
        }
    }
}
