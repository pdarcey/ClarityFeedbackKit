//
/* Project: ClarityFeedbackKit
   File: SubmissionSuccessView
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import SwiftUI

/// Shown in place of the report form once a submission succeeds — confirms it worked.
///
/// Deliberately doesn't link to the created GitHub issue: that repo is the developer's
/// internal plumbing (and may well be private), not something end users should see.
struct SubmissionSuccessView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Thanks for the report!", systemImage: "checkmark.circle")
        } description: {
            Text("Your report has been sent.")
        }
    }
}
