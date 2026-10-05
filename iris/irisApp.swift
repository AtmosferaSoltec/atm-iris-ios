//
//  irisApp.swift
//  iris
//
//  Created by Joel Maldonado on 4/10/26.
//

import SwiftUI

@main
struct irisApp: App {
    private let dependencies = AppDependencies.mock

    @State private var isShowingSplash = true

    var body: some Scene {
        WindowGroup {
            // Iris is landscape-only by design. Orientations and window sizes are all supported
            // as Apple asks (TN3192), and the landscape layout is scaled to fit when needed.
            IrisLandscapeCanvas {
                ZStack {
                    RootView(dependencies: dependencies)
                    if isShowingSplash {
                        IrisSplashView {
                            withAnimation(IrisMotion.smooth) { isShowingSplash = false }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .frame(minWidth: IrisSize.minimumWindow.width, minHeight: IrisSize.minimumWindow.height)
        }
        .windowResizability(.contentMinSize)
    }
}
