//
//  HomeView.swift
//  iris
//

import SwiftUI

/// Landing screen after sign-in: greeting, start-service hero and module tiles.
struct HomeView: View {
    let viewModel: HomeViewModel
    let account: AccountViewModel

    var body: some View {
        VStack(spacing: 0) {
            ConsoleTopBar(
                display: viewModel.display,
                account: account,
                sync: viewModel.syncService
            )

            if viewModel.initialSync != .ready {
                InitialSyncView(state: viewModel.initialSync) { viewModel.retryInitialSync() }
            } else if viewModel.isLoading {
                ProgressView()
                    .tint(IrisColor.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: IrisSpacing.xl) {
                        greeting
                        HomeHeroCard(viewModel: viewModel)
                        tiles
                    }
                    .padding(.horizontal, IrisSpacing.xxl)
                    .padding(.top, IrisSpacing.md)
                    .padding(.bottom, IrisSpacing.xxl)
                    .frame(maxWidth: IrisSize.contentWidth)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background { IrisBackground(isAnimated: false) }
        // Runs each time Home reappears, so changes made on other screens show up.
        .task { await viewModel.appear() }
        .task { await viewModel.observeChanges() }
        .task { await viewModel.runPeriodicSync() }
        .task { await viewModel.observeDisplay() }
    }

    // MARK: Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xs) {
            Text(viewModel.todayText)
                .font(IrisFont.overline)
                .tracking(IrisTracking.overline)
                .textCase(.uppercase)
                .foregroundStyle(IrisGradient.accent)

            Text("\(viewModel.greeting) \(Text(viewModel.session.church.name).foregroundStyle(IrisGradient.accent))")
                .font(.system(size: 44, weight: .medium, design: .serif))
                .tracking(IrisTracking.tight)
                .foregroundStyle(IrisColor.textPrimary)

            Group {
                if viewModel.display == nil {
                    Text("Conecta el TV antes de comenzar el servicio.")
                } else {
                    Text("Todo listo: el TV está conectado.")
                }
            }
            .font(IrisFont.subtitle)
            .foregroundStyle(IrisColor.textSecondary)
        }
    }

    // MARK: Tiles

    private var showsTime: Bool { viewModel.modules.timeControl }

    /// Servicios · Biblioteca, then Tiempos · Personas · Módulos.
    /// Without time control there is a single row: Servicios · Biblioteca · Módulos.
    private var tiles: some View {
        VStack(spacing: IrisSpacing.md) {
            HStack(alignment: .top, spacing: IrisSpacing.md) {
                ServicesTile(viewModel: viewModel)
                LibraryTile(viewModel: viewModel)
                if !showsTime {
                    ModulesTile(viewModel: viewModel)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            if showsTime {
                HStack(alignment: .top, spacing: IrisSpacing.md) {
                    TimesTile(viewModel: viewModel)
                    PeopleTile(viewModel: viewModel)
                    ModulesTile(viewModel: viewModel)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension HomeViewModel {
    /// Already-loaded view model for previews.
    static var preview: HomeViewModel { makePreview(store: InMemoryChurchStore()) }

    /// A church with no service types, people or records yet.
    static var emptyPreview: HomeViewModel { makePreview(store: InMemoryChurchStore(seed: .empty)) }

    private static func makePreview(store: InMemoryChurchStore) -> HomeViewModel {
        let viewModel = HomeViewModel(
            session: .preview,
            moduleSettings: MockModuleSettingsRepository(store: store, latency: .zero),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            people: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero),
            libraryRepository: MockLibraryRepository(latency: .zero),
            displayOutput: MockDisplayOutputService(),
            onNavigate: { _ in }
        )
        viewModel.apply(
            modules: store.modules,
            serviceTypes: store.serviceTypes,
            people: store.people,
            recordCount: store.records.count,
            library: .init(lyrics: 6, music: 5, images: 6, videos: 5),
            display: ExternalDisplay(name: "Sala principal", resolution: "1920 × 1080")
        )
        return viewModel
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    HomeView(viewModel: .preview, account: .preview())
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Sin servicios", traits: .landscapeLeft) {
    HomeView(viewModel: .emptyPreview, account: .preview())
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}
