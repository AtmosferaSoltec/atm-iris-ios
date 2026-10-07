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
    /// Music and videos can sit in the service before their file is on this iPad.
    var download: MediaAsset.DownloadState = .ready
    var onRetry: () -> Void = {}
    let onPresent: () -> Void

    private var isReady: Bool { download == .ready }

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
            .disabled(!isReady)
            .accessibilityHint(Text("Toca para presentar"))

            switch download {
            case .ready:
                Button(action: onPresent) {
                    Label(actionTitle, systemImage: actionIcon)
                }
                .buttonStyle(.irisPrimary)
                .frame(width: 300)
                .disabled(isActive)
            case .failed:
                Button(action: onRetry) {
                    Label("Reintentar descarga", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.irisPrimary)
                .frame(width: 300)
            case .notDownloaded, .downloading:
                Button {} label: {
                    Label(downloadTitle, systemImage: "icloud.and.arrow.down")
                        .contentTransition(.numericText())
                }
                .buttonStyle(.irisPrimary)
                .frame(width: 300)
                .disabled(true)
            }

            Text(hint)
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textTertiary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .animation(IrisMotion.smooth, value: isActive)
    }

    private var downloadTitle: LocalizedStringKey {
        if case let .downloading(progress) = download {
            return "Descargando… \(Int(progress * 100)) %"
        }
        return "Descargando…"
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
        switch download {
        case .failed: return "No se pudo descargar. Revisa la conexión a internet."
        case .notDownloaded, .downloading: return "Se descarga una sola vez y queda guardada en este iPad."
        case .ready: break
        }
        return switch kind {
        case .music: "La música suena en el salón; el TV no cambia. Contrólala desde el reproductor."
        case .video: "El video se muestra en el TV. Contrólalo desde el reproductor bajo la pantalla en vivo."
        default: "La imagen se muestra a pantalla completa en el TV."
        }
    }
}
