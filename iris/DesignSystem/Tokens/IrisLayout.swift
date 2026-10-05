//
//  IrisLayout.swift
//  iris
//

import SwiftUI

/// 4-pt spacing scale.
enum IrisSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

/// Corner radius scale. Always used with `.continuous` corners.
enum IrisRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
}

/// Fixed component dimensions.
enum IrisSize {
    static let controlHeight: CGFloat = 56
    static let segmentHeight: CGFloat = 44
    static let iconButton: CGFloat = 44
    static let authPanelWidth: CGFloat = 480
    static let readableWidth: CGFloat = 560
    /// Centered column of the church settings screens (Módulos, Personas).
    static let settingsColumnWidth: CGFloat = 720
    /// Widest content column of full screens (Inicio, Servicios).
    static let contentWidth: CGFloat = 1_280
    /// Smallest size the landscape design is laid out at. Smaller windows (portrait, narrow
    /// windows) get this canvas scaled down proportionally — see `IrisLandscapeCanvas`.
    /// The height leaves margin under an iPad mini in landscape (700 pt of safe area).
    static let landscapeCanvas = CGSize(width: 1_100, height: 640)
    /// Tallest height-to-width ratio of a scaled canvas: a landscape iPad (4:3).
    static let landscapeCanvasMaxAspect: CGFloat = 0.75
    /// Minimum window size (Apple's `contentMinSize` strategy): an iPad mini in portrait is
    /// 744 pt wide, so the scaled canvas never drops below ~2/3 of its real size.
    static let minimumWindow = CGSize(width: 744, height: 560)
}

/// Motion tokens. Calm, confident, never bouncy in a distracting way.
enum IrisMotion {
    static let snappy = Animation.snappy(duration: 0.3)
    static let smooth = Animation.smooth(duration: 0.45)
    static let gentle = Animation.spring(duration: 0.8, bounce: 0.1)
}
