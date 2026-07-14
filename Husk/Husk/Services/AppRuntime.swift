//
//  AppRuntime.swift
//  Husk
//

import Foundation

enum AppRuntime {
    /// True when running under Xcode Previews / Playgrounds.
    static var isXcodePreview: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1" { return true }
        if env["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return true }
        if env["PLAYGROUND_LOGGER_FILTER"] != nil { return true }
        return false
    }
}
