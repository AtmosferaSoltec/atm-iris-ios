//
//  RemoteScreen.swift
//  iris
//

import SwiftUI

/// The remote: the clock on top, the service on the left, the slides as cards, and the player at the bottom.
/// Everything shown is the computer's state; every tap is a command to it.
struct RemoteScreen: View {
    enum Sheet: Identifiable, Hashable {
        case bible, media, backgrounds, tools, addBlock
        case leader(Int)
        var id: String { "\(self)" }

        init?(argument: String) {
            switch argument {
            case "bible": self = .bible
            case "media": self = .media
            case "backgrounds": self = .backgrounds
            case "tools": self = .tools
            case "block": self = .addBlock
            default: return nil
            }
        }
    }

    let client: RemoteClient

    @State private var isConfirmingDisconnect = false
    /// The Bible's last book and chapter, while the app is open (never saved).
    @State private var biblePlace: BiblePlace? = {
        #if DEBUG
        // `-bible-place LUK:16` starts as if Lucas 16 had just been shown, to look at the reopened sheet.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-bible-place"), index + 1 < arguments.count {
            let parts = arguments[index + 1].split(separator: ":")
            if parts.count == 2, let chapter = Int(parts[1]) { return BiblePlace(bookId: String(parts[0]), chapter: chapter) }
        }
        #endif
        return nil
    }()

    /// `-sheet backgrounds|tools` opens a sheet at launch, to look at it directly.
    @State private var sheet: Sheet? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-sheet"), index + 1 < arguments.count else { return nil }
        return Sheet(argument: arguments[index + 1])
    }()

    var body: some View {
        if let state = client.state {
            remote(state)
        } else if client.isConsoleAway {
            consoleAway
        } else {
            ProgressView().tint(IrisColor.coral)
        }
    }

    private func remote(_ state: RemoteState) -> some View {
        let item = state.items.first { $0.id == state.openId } ?? state.items.first
        return VStack(spacing: IrisSpacing.sm) {
            header
            if let service = state.service {
                TimerBar(client: client, service: service, state: state, onLeader: { sheet = .leader($0) }, onAddBlock: { sheet = .addBlock })
            } else {
                NoServiceBar(client: client, state: state)
            }
            HStack(alignment: .top, spacing: IrisSpacing.md) {
                servicePanel(state, current: item).frame(width: 280)
                slidesPanel(state, item: item)
            }
            // Always on, like a remote's transport: it shows what plays even while another element is open.
            PlaybackBar(client: client, state: state, item: item)
        }
        .padding(IrisSpacing.md)
        .overlay(alignment: .top) {
            if client.phase == .reconnecting {
                IrisBanner(style: .info, message: "Reconectando con Iris…")
                    .frame(maxWidth: 420)
                    .padding(.top, IrisSpacing.sm)
            }
        }
        .sheet(item: $sheet) { sheet in
            Group {
                switch sheet {
                case .bible: BibleSheet(client: client, state: client.state ?? state, place: $biblePlace)
                case .media: MediaSheet(client: client, state: client.state ?? state)
                case .backgrounds: BackgroundsSheet(client: client, state: client.state ?? state)
                case .tools: ToolsSheet(client: client, state: client.state ?? state)
                case .addBlock: AddBlockSheet(client: client, state: client.state ?? state)
                case .leader(let index): LeaderSheet(client: client, state: client.state ?? state, blockIndex: index)
                }
            }
            .presentationBackground(IrisColor.canvasElevated)
        }
    }

    /// Paired, but Iris on the computer is in Settings or Times: the service screen is what the iPad drives.
    private var consoleAway: some View {
        VStack(spacing: IrisSpacing.md) {
            header
            Spacer()
            IrisSurface(padding: IrisSpacing.xl) {
                VStack(spacing: IrisSpacing.sm) {
                    Image(systemName: "display")
                        .font(.system(size: 40))
                        .foregroundStyle(IrisColor.coral)
                    Text("Conectado").font(IrisFont.title)
                    Text("En la computadora, vuelve a la pantalla del servicio para controlarla desde aquí.")
                        .font(IrisFont.callout)
                        .foregroundStyle(IrisColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 460)
            Spacer()
        }
        .padding(IrisSpacing.md)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: IrisSpacing.sm) {
            IrisWordmark(markSize: 28)
            HStack(spacing: IrisSpacing.xs) {
                Circle().fill(client.phase == .connected ? IrisColor.success : IrisColor.warning).frame(width: 8, height: 8)
                // "MacBook-Pro-de-Joel.local" is long: one line, the end cut, never pushing the buttons.
                Text((client.computerName ?? "Iris").replacingOccurrences(of: ".local", with: ""))
                    .font(IrisFont.calloutEmphasized)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, IrisSpacing.sm)
            .padding(.vertical, 6)
            .background(IrisColor.surface, in: Capsule())
            Spacer()
            headerButton("Biblia", "book.closed") { sheet = .bible }
            headerButton("Multimedia", "photo.stack") { sheet = .media }
            headerButton("Fondos", "photo.on.rectangle") { sheet = .backgrounds }
            headerButton("Herramientas", "wrench.and.screwdriver") { sheet = .tools }
            // Not an "×": it reads as "close this" and dropped the connection mid-service. It asks first.
            Button { isConfirmingDisconnect = true } label: {
                Label("Desconectar", systemImage: "wifi.slash")
                    .foregroundStyle(IrisColor.danger)
                    .padding(.horizontal, IrisSpacing.md)
            }
            .buttonStyle(.irisGlass)
            .overlay(Capsule().strokeBorder(IrisColor.danger.opacity(0.5), lineWidth: 1))
            .fixedSize()
            .confirmationDialog("¿Desconectar el iPad?", isPresented: $isConfirmingDisconnect, titleVisibility: .visible) {
                Button("Desconectar", role: .destructive) { client.disconnect() }
                Button("Seguir conectado", role: .cancel) {}
            } message: {
                Text("Para volver a conectar necesitarás el código que aparece en la computadora.")
            }
        }
    }

    private func headerButton(_ title: LocalizedStringKey, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).padding(.horizontal, IrisSpacing.md) }
            .buttonStyle(.irisGlass)
            .fixedSize()
    }

    // MARK: Service

    private func servicePanel(_ state: RemoteState, current: RemoteItem?) -> some View {
        VStack(alignment: .leading, spacing: IrisSpacing.xs) {
            IrisSectionHeader("Servicio") {
                Text(state.service?.name ?? state.churchName)
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textSecondary)
            }
            if state.items.allSatisfy({ $0.kind == .bible }) {
                Text("El servicio está vacío. Agrega canciones en la computadora.")
                    .font(IrisFont.caption)
                    .foregroundStyle(IrisColor.textSecondary)
                    .padding(IrisSpacing.xs)
            }
            ScrollView {
                VStack(spacing: IrisSpacing.xxs) {
                    ForEach(state.items.filter { $0.kind != .bible }) { item in
                        serviceRow(item, isCurrent: item.id == current?.id)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(IrisSpacing.sm)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(IrisColor.canvasElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: IrisRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: IrisRadius.lg).strokeBorder(IrisColor.stroke, lineWidth: 1))
    }

    private func serviceRow(_ item: RemoteItem, isCurrent: Bool) -> some View {
        Button {
            client.send(.select(id: item.id))
        } label: {
            HStack(spacing: IrisSpacing.sm) {
                Image(systemName: item.kind.systemImage)
                    .frame(width: 24)
                    .foregroundStyle(isCurrent ? IrisColor.coral : IrisColor.textSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(IrisFont.callout).lineLimit(1)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(IrisFont.caption)
                            .foregroundStyle(IrisColor.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, IrisSpacing.sm)
            .padding(.vertical, IrisSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: IrisRadius.sm)
                    .fill(isCurrent ? IrisColor.surfaceRaised : .clear)
            )
        }
        .buttonStyle(.irisPressable)
    }

    // MARK: Slides

    @ViewBuilder
    private func slidesPanel(_ state: RemoteState, item: RemoteItem?) -> some View {
        if let item {
            let liveSlide = state.live?.id == item.id ? state.live?.slide : nil
            let background = state.backgrounds.first { $0.id == state.backgroundId }
            VStack(alignment: .leading, spacing: IrisSpacing.sm) {
                HStack(spacing: IrisSpacing.sm) {
                    Text(item.title).font(IrisFont.title).lineLimit(1)
                    IrisChip(LocalizedStringKey(item.kind.title), systemImage: item.kind.systemImage)
                    Spacer()
                    if let background {
                        IrisChip(LocalizedStringKey(background.name), systemImage: "photo", tint: IrisColor.violet)
                    }
                    if state.live != nil && !state.isCleared { IrisLiveIndicator() }
                }
                SlideGrid(client: client, item: item, selectedSlide: liveSlide) { index in
                    client.send(.showSlide(id: item.id, slide: index))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            Spacer()
        }
    }
}

#Preview {
    ZStack {
        IrisBackground(isAnimated: false).ignoresSafeArea()
        RemoteScreen(client: RemoteClient(demo: DemoState.state, computerName: "PC del santuario"))
    }
    .preferredColorScheme(.dark)
}
