//
//  UpdateRequiredView.swift
//  iris
//

import SwiftUI

/// Blocks the app until the new version is installed. No way to dismiss it.
struct UpdateRequiredView: View {
    let notice: AppUpdateNotice

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            IrisBackground(isAnimated: false)

            IrisSurface {
                VStack(alignment: .leading, spacing: IrisSpacing.lg) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(IrisGradient.accent)

                    VStack(alignment: .leading, spacing: IrisSpacing.xs) {
                        Text("Hay una nueva versión de Iris")
                            .font(IrisFont.title)
                            .foregroundStyle(IrisColor.textPrimary)
                        Text("Para continuar, actualiza a la versión \(notice.latestVersion).")
                            .font(IrisFont.subtitle)
                            .foregroundStyle(IrisColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let notes = notice.notes {
                            Text(notes)
                                .font(IrisFont.callout)
                                .foregroundStyle(IrisColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let url = notice.downloadURL {
                        Button { openURL(url) } label: {
                            Label("Actualizar", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.irisPrimary)
                    } else {
                        Text("Abre TestFlight o la App Store y actualiza Iris.")
                            .font(IrisFont.callout)
                            .foregroundStyle(IrisColor.textSecondary)
                    }
                }
                .frame(maxWidth: 480, alignment: .leading)
            }
            .padding(IrisSpacing.xl)
        }
    }
}

#Preview("Update required", traits: .landscapeLeft) {
    UpdateRequiredView(
        notice: AppUpdateNotice(latestVersion: "1.0.1", downloadURL: URL(string: "https://testflight.apple.com"), notes: "Mejoras en la consola.")
    )
    .preferredColorScheme(.dark)
}
