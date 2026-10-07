//
//  LiveConsoleView.swift
//  iris
//

import SwiftUI

/// The live control console, in two columns:
/// service order + live screen on the left, block timer and slides of the open item on the right.
struct LiveConsoleView: View {
    @Bindable var viewModel: LiveConsoleViewModel
    var onExit: (() -> Void)?
    var onOpenTimes: () -> Void = {}
    let account: AccountViewModel

    private let wideLayoutMinWidth: CGFloat = 1_150

    var body: some View {
        VStack(spacing: 0) {
            ConsoleTopBar(
                title: viewModel.serviceTitle,
                date: viewModel.service?.date,
                display: viewModel.display,
                account: account,
                onExit: onExit.map { exit in { viewModel.requestExit(then: exit) } }
            )

            content
        }
        .background { IrisBackground(isAnimated: false) }
        .task { await viewModel.load() }
        .task { await viewModel.runPlaybackClock() }
        .task { await viewModel.runBlockClock() }
        .task { await viewModel.runCountdownClock() }
        .task { await viewModel.observeDisplay() }
        .task { await viewModel.observeLibrary() }
        .alert("El servicio sigue en curso", isPresented: $viewModel.isConfirmingExit) {
            Button("Terminar y guardar") {
                Task { await viewModel.finishAndExit() }
            }
            Button("Salir sin guardar", role: .destructive) {
                viewModel.exitWithoutSaving()
            }
            Button("Cancelar", role: .cancel) {
                viewModel.cancelExit()
            }
        }
        .overlay(alignment: .bottom) { undoToast }
        .animation(IrisMotion.smooth, value: viewModel.recentlyRemoved)
        .sheet(item: $viewModel.addSheet) { addSheet in
            AddToServiceView(viewModel: addSheet)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
                .tint(IrisColor.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .failed(message):
            ContentUnavailableView {
                Label(message, systemImage: "exclamationmark.triangle")
            } actions: {
                Button("Reintentar") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(.irisPill)
            }
            .foregroundStyle(IrisColor.textSecondary)

        case .loaded:
            GeometryReader { proxy in
                HStack(alignment: .top, spacing: IrisSpacing.md) {
                    sidebar
                        .frame(width: proxy.size.width >= wideLayoutMinWidth ? 340 : 300)
                    workspaceColumn
                }
            }
            .padding([.horizontal, .bottom], IrisSpacing.md)
        }
    }

    // MARK: Columns

    /// Column 1: service order on top, live screen below.
    private var sidebar: some View {
        VStack(spacing: IrisSpacing.md) {
            IrisSurface(padding: IrisSpacing.md, cornerRadius: IrisRadius.xl) {
                ServiceOrderView(viewModel: viewModel)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            IrisSurface(padding: IrisSpacing.sm, cornerRadius: IrisRadius.xl) {
                VStack(spacing: IrisSpacing.md) {
                    LiveScreenView(frame: viewModel.liveFrame, typography: viewModel.typography)
                        .environment(\.projectionVideoPlayer, viewModel.videoPlayer)

                    if let playback = viewModel.playback {
                        NowPlayingView(
                            playback: playback,
                            onTogglePlay: { viewModel.togglePlayPause() },
                            onRestart: { viewModel.restartPlayback() },
                            onStop: { withAnimation(IrisMotion.smooth) { viewModel.stopPlayback() } },
                            onToggleLoop: { viewModel.toggleLooping() },
                            onSeek: { viewModel.seek(to: $0) }
                        )
                        .padding(.bottom, IrisSpacing.xs)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .animation(IrisMotion.smooth, value: viewModel.playback?.itemID)
        }
    }

    @ViewBuilder
    private var undoToast: some View {
        if let removed = viewModel.recentlyRemoved {
            UndoToast(message: String(localized: "Se quitó «\(removed.item.title)»")) {
                withAnimation(IrisMotion.smooth) { viewModel.undoRemoval() }
            }
            .padding(.bottom, IrisSpacing.xl)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Column 2: the block timer (when the service tracks time) above the workspace.
    private var workspaceColumn: some View {
        VStack(spacing: IrisSpacing.md) {
            if viewModel.showsBlockTimer {
                BlockTimerBar(viewModel: viewModel, onOpenTimes: { onOpenTimes() })
            }
            IrisSurface(padding: IrisSpacing.lg, cornerRadius: IrisRadius.xl) {
                SlideWorkspaceView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    LiveConsoleView(viewModel: .preview, account: .preview())
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Video", traits: .landscapeLeft) {
    let viewModel = LiveConsoleViewModel.preview
    if let video = viewModel.items.first(where: { $0.kind == .video }) {
        viewModel.selectItem(video.id)
        viewModel.presentSelectedMedia()
        viewModel.seek(to: 52)
    }
    return LiveConsoleView(viewModel: viewModel, account: .preview())
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Sin Biblia ni multimedia", traits: .landscapeLeft) {
    LiveConsoleView(viewModel: .limitedPreview, account: .preview())
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

#Preview("Servicio iniciado", traits: .landscapeLeft) {
    LiveConsoleView(viewModel: .startedServicePreview, onExit: {}, account: .preview())
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "es"))
}

extension LiveConsoleViewModel {
    /// Already-loaded view model for previews.
    static var preview: LiveConsoleViewModel { makePreview(modules: ChurchModules()) }

    /// Without Biblia and Multimedia: no Bible button, no media items.
    static var limitedPreview: LiveConsoleViewModel {
        makePreview(modules: ChurchModules(bible: false, multimedia: false, timeControl: true))
    }

    /// Culto general just started from Home: empty list, blocks not started.
    static var startedServicePreview: LiveConsoleViewModel {
        let store = InMemoryChurchStore()
        let culto = store.serviceTypes.first
        return makePreview(
            modules: ChurchModules(),
            serviceType: culto,
            people: store.people,
            plan: ServicePlan(id: UUID(), title: culto?.name ?? "", date: .now, items: [])
        )
    }

    static func makePreview(
        modules: ChurchModules,
        serviceType: ServiceType? = nil,
        people: [Person] = [],
        plan: ServicePlan = MockServicePlanRepository.sample
    ) -> LiveConsoleViewModel {
        let store = InMemoryChurchStore()
        let viewModel = LiveConsoleViewModel(
            session: .preview,
            serviceType: serviceType,
            modules: modules,
            people: people,
            servicePlanRepository: MockServicePlanRepository(latency: .zero),
            projectionSettings: MockProjectionSettingsRepository(store: InMemoryChurchStore(), latency: .zero),
            backgroundRepository: MockBackgroundRepository(),
            bibleRepository: MockBibleRepository(),
            libraryRepository: MockLibraryRepository(),
            mediaPlayback: MockMediaPlaybackService(),
            displayOutput: MockDisplayOutputService(),
            serviceTypes: MockServiceTypeRepository(store: store, latency: .zero),
            peopleRepository: MockPeopleRepository(store: store, latency: .zero),
            timeRecords: MockTimeRecordRepository(store: store, latency: .zero)
        )
        viewModel.apply(
            plan: plan,
            backgrounds: MockBackgroundRepository.sample,
            display: ExternalDisplay(name: "Sala principal", resolution: "1920 × 1080")
        )
        return viewModel
    }
}
