//
//  irisApp.swift
//  iris
//

import SwiftUI

@main
struct irisApp: App {
    var body: some Scene {
        WindowGroup {
            // Iris is landscape-only by design (see IrisLandscapeCanvas).
            IrisLandscapeCanvas {
                AppRoot()
            }
            .frame(minWidth: IrisSize.minimumWindow.width, minHeight: IrisSize.minimumWindow.height)
        }
        .windowResizability(.contentMinSize)
    }
}
