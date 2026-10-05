//
//  InitialSyncView.swift
//  iris
//

import SwiftUI

/// Covers Home while the church is downloaded for the first time on this iPad.
struct InitialSyncView: View {
    let state: InitialSyncState
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: IrisSpacing.lg) {
            emblem
            VStack(spacing: IrisSpacing.xs) {
                title
                    .font(IrisFont.title)
                    .foregroundStyle(IrisColor.textPrimary)
                detail
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
            }
            if showsRetry {
                Button("Reintentar") { onRetry() }
                    .buttonStyle(.irisGlass)
                    .fixedSize()
            }
        }
        .frame(maxWidth: IrisSize.readableWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var showsRetry: Bool {
        switch state {
        case .needsConnection, .failed: true
        case .ready, .loading: false
        }
    }

    @ViewBuilder
    private var emblem: some View {
        switch state {
        case .loading, .ready:
            ProgressView()
                .controlSize(.large)
                .tint(IrisColor.textSecondary)
                .frame(width: 64, height: 64)
        case .needsConnection, .failed:
            Image(systemName: "icloud.slash")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(IrisGradient.accent)
                .frame(width: 64, height: 64)
                .background(IrisColor.surface, in: Circle())
                .overlay(Circle().strokeBorder(IrisColor.stroke))
        }
    }

    @ViewBuilder
    private var title: some View {
        switch state {
        case .loading, .ready: Text("Preparando tu iglesia…")
        case .needsConnection: Text("Sin conexión")
        case .failed: Text("No pudimos descargar tu iglesia")
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch state {
        case let .loading(pages) where pages > 0:
            Text("Descargando canciones, servicios y registros · \(pages) partes listas")
        case .loading, .ready:
            Text("Descargando canciones, servicios y registros para que funcione sin conexión.")
        case .needsConnection:
            Text("Necesitas conexión para descargar tu iglesia la primera vez.")
        case let .failed(message):
            Text(message)
        }
    }
}

#Preview("Cargando", traits: .landscapeLeft) {
    InitialSyncView(state: .loading(pages: 0), onRetry: {})
        .background(IrisColor.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Sin conexión", traits: .landscapeLeft) {
    InitialSyncView(state: .needsConnection, onRetry: {})
        .background(IrisColor.canvas)
        .preferredColorScheme(.dark)
}
