//
//  IrisButtonStyles.swift
//  iris
//

import SwiftUI

/// Primary call to action: warm spectrum capsule with a soft glow.
struct IrisPrimaryButtonStyle: ButtonStyle {
    var isLoading = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IrisFont.bodyEmphasized)
            .foregroundStyle(IrisColor.textInverse)
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView()
                        .tint(IrisColor.textInverse)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: IrisSize.controlHeight)
            .background {
                Capsule()
                    .fill(IrisGradient.accent)
                    .shadow(color: IrisColor.coral.opacity(isEnabled ? 0.4 : 0), radius: 22, y: 10)
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    .blendMode(.overlay)
            }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .allowsHitTesting(!isLoading)
            .animation(IrisMotion.snappy, value: configuration.isPressed)
            .animation(IrisMotion.snappy, value: isLoading)
    }
}

/// Secondary action on Liquid Glass.
struct IrisGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IrisFont.bodyEmphasized)
            .foregroundStyle(IrisColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: IrisSize.controlHeight)
            .glassEffect(.regular.interactive(), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(IrisMotion.snappy, value: configuration.isPressed)
    }
}

/// Circular glass button for a single SF Symbol. `isActive` tints it to show an on state.
struct IrisIconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .semibold))
            .symbolVariant(isActive ? .fill : .none)
            .foregroundStyle(isActive ? IrisColor.textInverse : IrisColor.textPrimary)
            .frame(width: IrisSize.iconButton, height: IrisSize.iconButton)
            .glassEffect(isActive ? .regular.tint(IrisColor.coral).interactive() : .regular.interactive(), in: .circle)
            .animation(IrisMotion.snappy, value: isActive)
    }
}

/// Quiet inline text action.
struct IrisLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IrisFont.calloutEmphasized)
            .foregroundStyle(configuration.isPressed ? IrisColor.textPrimary : IrisColor.textSecondary)
            .contentShape(Rectangle())
            .animation(IrisMotion.snappy, value: configuration.isPressed)
    }
}

/// Small glass pill for secondary toolbar-level actions.
struct IrisPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(IrisFont.label)
            .foregroundStyle(IrisColor.textPrimary)
            .padding(.horizontal, IrisSpacing.md - 2)
            .frame(height: 36)
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// Adds press feedback to fully custom button content.
struct IrisPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(IrisMotion.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == IrisPillButtonStyle {
    static var irisPill: IrisPillButtonStyle { .init() }
}

extension ButtonStyle where Self == IrisPressableButtonStyle {
    static var irisPressable: IrisPressableButtonStyle { .init() }
}

extension ButtonStyle where Self == IrisPrimaryButtonStyle {
    static var irisPrimary: IrisPrimaryButtonStyle { .init() }
    static func irisPrimary(isLoading: Bool) -> IrisPrimaryButtonStyle { .init(isLoading: isLoading) }
}

extension ButtonStyle where Self == IrisGlassButtonStyle {
    static var irisGlass: IrisGlassButtonStyle { .init() }
}

extension ButtonStyle where Self == IrisIconButtonStyle {
    static var irisIcon: IrisIconButtonStyle { .init() }
    static func irisIcon(isActive: Bool) -> IrisIconButtonStyle { .init(isActive: isActive) }
}

extension ButtonStyle where Self == IrisLinkButtonStyle {
    static var irisLink: IrisLinkButtonStyle { .init() }
}

#Preview {
    VStack(spacing: 24) {
        Button("Entrar") {}.buttonStyle(.irisPrimary)
        Button("Entrar") {}.buttonStyle(.irisPrimary(isLoading: true))
        Button("Cerrar sesión") {}.buttonStyle(.irisGlass)
        HStack(spacing: 24) {
            Button {} label: { Image(systemName: "xmark") }.buttonStyle(.irisIcon)
            Button("¿Olvidaste tu contraseña?") {}.buttonStyle(.irisLink)
        }
    }
    .padding(48)
    .frame(width: 480)
    .background(IrisBackground())
}
