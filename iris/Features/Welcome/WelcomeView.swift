//
//  WelcomeView.swift
//  iris
//

import SwiftUI

/// First-run explanation: what Iris does and where lyrics, music and media are uploaded.
struct WelcomeView: View {
    let onContinue: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            IrisBackground(isAnimated: false)

            ScrollView {
                IrisSurface {
                    VStack(alignment: .leading, spacing: IrisSpacing.xl) {
                        VStack(alignment: .leading, spacing: IrisSpacing.sm) {
                            Text("Te damos la bienvenida a Iris")
                                .font(IrisFont.headline)
                                .foregroundStyle(IrisColor.textPrimary)
                            Text("Iris proyecta letras, versículos y multimedia en la pantalla del templo, y tú diriges todo el servicio desde este iPad.")
                                .font(IrisFont.subtitle)
                                .foregroundStyle(IrisColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: IrisSpacing.md) {
                            step(
                                icon: "globe",
                                title: "Sube tu contenido en la web",
                                detail: "Las letras, la música y la multimedia se suben desde la web de Iris. Aquí solo las usas."
                            )
                            step(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Aparecen aquí solas",
                                detail: "Lo que subas en la web se sincroniza con el iPad y con la app de Windows."
                            )
                            step(
                                icon: "play.rectangle",
                                title: "Dirige el servicio",
                                detail: "Elige el servicio, agrega lo que vas a proyectar y envíalo a la pantalla."
                            )
                        }

                        VStack(spacing: IrisSpacing.sm) {
                            Button { openURL(WebLinks.app) } label: {
                                Label("Abrir la web de Iris", systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(.irisPrimary)

                            Button("Empezar", action: onContinue)
                                .buttonStyle(.irisLink)
                                .padding(.top, IrisSpacing.xs)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: 640)
                .padding(IrisSpacing.xl)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func step(icon: String, title: LocalizedStringResource, detail: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: IrisSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(IrisGradient.accent)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(IrisFont.bodyEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                Text(detail)
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Welcome", traits: .landscapeLeft) {
    WelcomeView(onContinue: {})
        .preferredColorScheme(.dark)
}
