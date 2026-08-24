//
/* Project: ClarityFeedbackKit
   File: DeviceInfo
   Created by Paul Darcey on 24/8/2026
   © 2026 Xerodonia Pty Ltd. All rights reserved
------------------------------------------------ */
import Foundation
import Darwin

/// App/OS/device metadata auto-attached to every submission, matching the footer the
/// relay renders into the created GitHub issue. Deliberately avoids `UIKit` — hardware
/// identifiers come from `uname(2)`, which works identically on macOS and iOS — so this
/// package stays free of any platform-specific UI framework import.
enum DeviceInfo {
    /// e.g. `"1.2.3 (45)"`, falling back to just the short version, or `nil` if this
    /// process has no bundle version info at all (e.g. running under `swift test`).
    static var appVersion: String? {
        guard let info = Bundle.main.infoDictionary else { return nil }
        let shortVersion = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String
        switch (shortVersion, build) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), .none):
            return version
        case let (.none, .some(build)):
            return build
        case (.none, .none):
            return nil
        }
    }

    /// e.g. `"macOS 26.0.0"` / `"iOS 26.0.0"`.
    static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let numberString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #if os(macOS)
        return "macOS \(numberString)"
        #elseif os(iOS)
        return "iOS \(numberString)"
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    /// The raw hardware identifier (e.g. `"MacBookPro18,3"`, `"iPhone15,3"`) read via
    /// `uname(2)` — not a friendly marketing name. Good enough for a bug-report footer;
    /// mapping to friendly names is a fast-follow if it turns out to matter.
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result += String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "Unknown" : identifier
    }
}
