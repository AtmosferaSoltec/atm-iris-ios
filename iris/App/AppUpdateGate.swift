//
//  AppUpdateGate.swift
//  iris
//

import Foundation
import Observation

/// Holds the "update required" notice. The notice never shows while a service is running:
/// the console works with what it has until the person comes back to Inicio.
@MainActor
@Observable
final class AppUpdateGate {
    private(set) var notice: AppUpdateNotice?
    /// Set by the signed-in screens: `true` while the live console is open.
    var isServiceLive = false

    private let service: any AppVersionService

    init(service: any AppVersionService) {
        self.service = service
    }

    /// The notice to show right now.
    var visibleNotice: AppUpdateNotice? {
        isServiceLive ? nil : notice
    }

    func refresh() async {
        // Once required, it stays required until the app is replaced: nothing to ask again.
        guard notice == nil else { return }
        notice = await service.requiredUpdate()
    }
}
