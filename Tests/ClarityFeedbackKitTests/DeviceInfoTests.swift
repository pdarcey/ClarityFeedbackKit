//
/* Project: ClarityFeedbackKit
   File: DeviceInfoTests
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Testing
@testable import ClarityFeedbackKit

@Suite("DeviceInfo")
struct DeviceInfoTests {
    @Test("osVersion is never empty")
    func osVersionIsNeverEmpty() {
        #expect(!DeviceInfo.osVersion.isEmpty)
    }

    @Test("osVersion is prefixed with the platform name")
    func osVersionHasPlatformPrefix() {
        #if os(macOS)
        #expect(DeviceInfo.osVersion.hasPrefix("macOS "))
        #elseif os(iOS)
        #expect(DeviceInfo.osVersion.hasPrefix("iOS "))
        #endif
    }

    @Test("deviceModel is never empty")
    func deviceModelIsNeverEmpty() {
        #expect(!DeviceInfo.deviceModel.isEmpty)
    }

    @Test("appVersion doesn't crash when no bundle version info is present")
    func appVersionDoesNotCrashUnderTestHost() {
        // `swift test`'s process bundle typically has no CFBundleShortVersionString, so
        // this is expected to be nil — the point of this test is just that reading it is
        // safe, not any particular value.
        _ = DeviceInfo.appVersion
    }
}
