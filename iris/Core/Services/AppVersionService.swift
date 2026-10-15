//
//  AppVersionService.swift
//  iris
//

import Foundation

/// An update the person must install before continuing.
nonisolated struct AppUpdateNotice: Equatable, Sendable {
    let latestVersion: String
    /// Where "Actualizar" goes (TestFlight or App Store).
    let downloadURL: URL?
    let notes: String?
}

/// Asks the API whether this version is still valid (contract §17).
protocol AppVersionService: Sendable {
    /// `nil` when the app is current **or when it cannot be known**: no connection, API down, any error.
    /// A failed check never blocks anyone.
    func requiredUpdate() async -> AppUpdateNotice?
}

nonisolated struct LiveAppVersionService: AppVersionService {
    let client: APIClient
    /// `CFBundleShortVersionString` of this build.
    let currentVersion: String

    private struct Check: Decodable, Sendable {
        let latestVersion: String
        let updateRequired: Bool
        let downloadUrl: String?
        let notes: String?
    }

    func requiredUpdate() async -> AppUpdateNotice? {
        let request = APIRequest(
            .get,
            "/app-version",
            query: [URLQueryItem(name: "platform", value: "ios"), URLQueryItem(name: "version", value: currentVersion)],
            requiresAuth: false
        )
        guard let check = try? await client.send(request, as: Check.self), check.updateRequired else { return nil }
        return AppUpdateNotice(
            latestVersion: check.latestVersion,
            downloadURL: check.downloadUrl.flatMap(URL.init(string:)),
            notes: check.notes
        )
    }
}

/// Previews, tests and `-IrisDataMode mock`: never asks for an update.
nonisolated struct MockAppVersionService: AppVersionService {
    var notice: AppUpdateNotice?

    func requiredUpdate() async -> AppUpdateNotice? { notice }
}
