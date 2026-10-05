//
//  AppConfig.swift
//  iris
//

import Foundation

/// Where the app's data comes from.
nonisolated enum DataMode: String, Sendable {
    /// In-memory sample data (previews, tests and `-IrisDataMode mock`).
    case mock
    /// The real API, through the local copy.
    case live
}

/// Build- and launch-time configuration.
nonisolated struct AppConfig: Sendable {
    /// `nil` when the build has no API configured (Release, for now).
    let apiBaseURL: URL?
    let dataMode: DataMode

    static let current = AppConfig(bundle: .main, defaults: .standard)

    init(apiBaseURL: URL?, dataMode: DataMode) {
        self.apiBaseURL = apiBaseURL
        self.dataMode = dataMode
    }

    /// Reads `IrisAPIBaseURL` from the Info.plist (set by the xcconfig) and the `-IrisDataMode` launch argument.
    init(bundle: Bundle, defaults: UserDefaults) {
        let rawURL = (bundle.object(forInfoDictionaryKey: "IrisAPIBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        apiBaseURL = rawURL.isEmpty ? nil : URL(string: rawURL)
        dataMode = defaults.string(forKey: "IrisDataMode").flatMap(DataMode.init(rawValue:)) ?? .live
    }
}
