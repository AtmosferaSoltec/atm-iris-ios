//
//  ModulesView.swift
//  iris
//

import SwiftUI

/// Church modules with a switch each. What is turned off disappears from Home and the console.
struct ModulesView: View {
    @State private var viewModel: ModulesViewModel

    init(viewModel: ModulesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .tint(IrisColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    IrisSurface {
                        VStack(alignment: .leading, spacing: IrisSpacing.lg) {
                            header
                            if let errorMessage = viewModel.errorMessage {
                                IrisBanner(style: .error, message: errorMessage)
                            }
                            moduleList
                        }
                    }
                    .frame(maxWidth: IrisSize.settingsColumnWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, IrisSpacing.xl)
                    .padding(.top, IrisSpacing.md)
                    .padding(.bottom, IrisSpacing.xxl)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task { await viewModel.load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xs) {
            Text("Módulos")
                .font(IrisFont.headline)
                .tracking(IrisTracking.tight)
                .foregroundStyle(IrisColor.textPrimary)
            Text("Elige qué partes de Iris usa tu iglesia. Lo que apagues desaparece de la consola.")
                .font(IrisFont.callout)
                .foregroundStyle(IrisColor.textSecondary)
        }
    }

    private var moduleList: some View {
        VStack(spacing: 0) {
            ForEach(ModulesViewModel.Module.allCases) { module in
                if module != ModulesViewModel.Module.allCases.first {
                    Divider()
                        .overlay(IrisColor.stroke)
                }
                ModuleRow(
                    module: module,
                    isOn: Binding(
                        get: { viewModel.isOn(module) },
                        set: { viewModel.setModule(module, isOn: $0) }
                    )
                )
                if module == .timeControl, viewModel.showsTimeControlNote {
                    IrisBanner(
                        style: .info,
                        message: String(localized: "Los tiempos guardados se conservan. Puedes volver a activarlo cuando quieras.")
                    )
                    .padding(.bottom, IrisSpacing.md)
                    .transition(.opacity)
                }
            }
        }
        .animation(IrisMotion.smooth, value: viewModel.showsTimeControlNote)
    }
}

/// Tinted icon, name, description and switch.
private struct ModuleRow: View {
    let module: ModulesViewModel.Module
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: IrisSpacing.md) {
            Image(systemName: module.systemImage)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(module.tint)
                .frame(width: 40, height: 40)
                .background(module.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: IrisRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(module.title)
                    .font(IrisFont.bodyEmphasized)
                    .foregroundStyle(IrisColor.textPrimary)
                Text(module.summary)
                    .font(IrisFont.callout)
                    .foregroundStyle(IrisColor.textSecondary)
            }

            Spacer(minLength: IrisSpacing.md)

            Toggle(isOn: $isOn) {
                Text(module.title)
            }
            .labelsHidden()
            .tint(IrisColor.coral)
            .disabled(module.isAlwaysOn)
        }
        .padding(.vertical, IrisSpacing.md)
    }
}

private extension ModulesViewModel.Module {
    var title: LocalizedStringResource {
        switch self {
        case .lyrics: "Letras"
        case .bible: "Biblia"
        case .multimedia: "Multimedia"
        case .timeControl: "Control de tiempo"
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .lyrics: "Proyecta letras de canciones y anuncios. Siempre activo."
        case .bible: "Busca y proyecta versículos por libro, capítulo y versículo."
        case .multimedia: "Música, imágenes y videos en la biblioteca y el reproductor."
        case .timeControl: "Mide los bloques de cada servicio y guarda sus tiempos."
        }
    }

    var systemImage: String {
        switch self {
        case .lyrics: ServiceItem.Kind.song.systemImage
        case .bible: ServiceItem.Kind.scripture.systemImage
        case .multimedia: ServiceItem.Kind.video.systemImage
        case .timeControl: "timer"
        }
    }

    var tint: Color {
        switch self {
        case .lyrics: IrisColor.ember
        case .bible: IrisColor.violet
        case .multimedia: IrisColor.rose
        case .timeControl: IrisColor.coral
        }
    }
}

extension ModulesViewModel {
    /// Already-loaded view model for previews, everything on.
    static var preview: ModulesViewModel { makePreview(ChurchModules()) }

    /// Multimedia and time control off: shows the time-control note.
    static var partialPreview: ModulesViewModel {
        makePreview(ChurchModules(bible: true, multimedia: false, timeControl: false))
    }

    private static func makePreview(_ modules: ChurchModules) -> ModulesViewModel {
        let store = InMemoryChurchStore()
        store.modules = modules
        let viewModel = ModulesViewModel(moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero))
        viewModel.apply(modules: modules)
        return viewModel
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    ModulesView(viewModel: .preview)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Sin control de tiempo", traits: .landscapeLeft) {
    ModulesView(viewModel: .partialPreview)
        .background { IrisBackground(isAnimated: false) }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}
