//
/* Project: ClarityFeedbackKit
   File: FeedbackMetadataFooter
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import SwiftUI

/// Read-only display of what gets attached to every report — app version, OS version,
/// device model — so the reporter can see it's included without needing to type it
/// themselves.
struct FeedbackMetadataFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let appVersion = DeviceInfo.appVersion {
                LabeledContent("App version", value: appVersion)
            }
            LabeledContent("OS version", value: DeviceInfo.osVersion)
            LabeledContent("Device", value: DeviceInfo.deviceModel)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
