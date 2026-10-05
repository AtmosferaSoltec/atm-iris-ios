//
//  irisApp.swift
//  iris
//
//  Created by Joel Maldonado on 4/10/26.
//

import SwiftUI

@main
struct irisApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: IrisAppDelegate
    private let dependencies = AppDependencies.make(.current)

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

/// Lets background media downloads finish while the app is suspended, and gives the TV its own scene.
final class IrisAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let configuration = UISceneConfiguration(name: "TV", sessionRole: connectingSceneSession.role)
            configuration.delegateClass = ExternalDisplaySceneDelegate.self
            return configuration
        }
        // Everything else is SwiftUI's own window.
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == MediaDownloader.sessionIdentifier else { return completionHandler() }
        // UIKit calls it back on the main queue, where the downloader invokes it.
        nonisolated(unsafe) let handler = completionHandler
        MediaDownloader.shared.setBackgroundCompletion { handler() }
    }
}
