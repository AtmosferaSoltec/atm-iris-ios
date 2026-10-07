//
//  MediaStageView.swift
//  iris
//

import SwiftUI

/// Workspace for a music, video or image item: one large card and one action.
/// Once playing, the controls live in the mini player under the live screen.
struct MediaStageView: View {
    let kind: ServiceItem.Kind
    let frame: ProjectionFrame
    var typography = ProjectionSettings()
    let isActive: Bool
    let onPresent: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: IrisRadius.lg, style: .continuous)

        VStack(spacing: IrisSpacing.lg) {
            Spacer(minLength: 0)

            Button(action: onPresent) {
                ProjectionCanvas(frame: frame, cornerRadius: IrisRadius.lg, typography: typography)
                    .overlay {
                        shape.strokeBorder(
                            isActive ? AnyShapeStyle(IrisGradient.accent) : AnyShapeStyle(IrisColor.stroke),
                            lineWidth: isActive ? 3 : 1
                        )
                    }
                    .overlay(alignment: .topLeading) {
                        if isActive {
                            IrisLiveIndicator(title: activeBadge)
                                .padding(IrisSpacing.sm)
                                .transition(.opacity)
                        }
                    }
                    .shadow(color: isActive ? IrisColor.coral.opacity(0.3) : .black.opacity(0.4), radius: 24, y: 8)
            }
            .buttonStyle(.irisPressable)
            .frame(maxWidth: 640)
            .accessibilityHint(Text("Toca para presentar"))

            Button(action: onPresent) {
                Label(actionTitle, systemImage: actionIcon)
            }
            .buttonStyle(.irisPrimary)
            .frame(width: 300)
            .disabled(isActive)

            Text(hint)
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textTertiary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .animation(IrisMotion.smooth, value: isActive)
    }

    private var activeBadge: LocalizedStringKey {
        kind == .image ? "EN PANTALLA" : "REPRODUCIENDO"
    }

    private var actionTitle: LocalizedStringKey {
        switch (kind, isActive) {
        case (.image, false): "Mostrar en el TV"
        case (.image, true): "En pantalla"
        case (_, false): "Reproducir"
        case (_, true): "Reproduciendo"
        }
    }

    private var actionIcon: String {
        kind == .image ? "tv" : "play.fill"
    }

    private var hint: LocalizedStringKey {
        switch kind {
        case .music: "La música suena en el salón; el TV no cambia. Contrólala desde el reproductor."
        case .video: "El video se muestra en el TV. Contrólalo desde el reproductor bajo la pantalla en vivo."
        default: "La imagen se muestra a pantalla completa en el TV."
        }
    }
}
