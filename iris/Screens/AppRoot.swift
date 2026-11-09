//
//  AppRoot.swift
//  iris
//

import SwiftUI

/// Scanner first, every time; the remote once Iris on the computer has accepted the QR's secret.
struct AppRoot: View {
    /// `-demo` shows the remote with sample content and no computer (screenshots, previews).
    @State private var client: RemoteClient = ProcessInfo.processInfo.arguments.contains("-demo")
        ? RemoteClient(demo: DemoState.state, computerName: "PC del santuario")
        : RemoteClient()

    private var isInRemote: Bool { client.phase == .connected || client.phase == .reconnecting }

    var body: some View {
        ZStack {
            IrisBackground(isAnimated: !isInRemote)
                .ignoresSafeArea()

            if isInRemote {
                RemoteScreen(client: client)
                    .transition(.opacity)
            } else {
                PairingScreen(client: client)
                    .transition(.opacity)
            }
        }
        .animation(IrisMotion.smooth, value: isInRemote)
        .preferredColorScheme(.dark)
        #if DEBUG
        .task { await runDebugScript() }
        #endif
    }

    #if DEBUG
    /// Launch arguments to exercise the real connection without touching the screen (simulator, CI):
    /// `-link 'iris://pair?v=1&c=...&p=...&h=...'` pairs without the camera, `-show 1` then projects that slide of the first item.
    private func runDebugScript() async {
        let arguments = ProcessInfo.processInfo.arguments
        func value(of flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        guard let text = value(of: "-link"), case .success(let link) = PairingLink.parse(text) else { return }
        client.connect(link: link)
        if arguments.contains("-exercise") {
            // Every new command once, in the order an operator would use them.
            for _ in 0..<100 where client.state == nil { try? await Task.sleep(for: .milliseconds(100)) }
            guard let state = client.state else { return }
            if let type = state.serviceTypes?.first { client.send(.chooseService(id: type.id)) }
            try? await Task.sleep(for: .milliseconds(500))
            client.send(.nextBlock)
            try? await Task.sleep(for: .milliseconds(500))
            client.send(.setLeader(block: 0, personId: nil, name: "Ana Pérez"))
            client.send(.addBlock(name: "Santa cena", minutes: 10, at: 1))
            if let media = state.library?.first { client.send(.presentMedia(id: media.id)) }
            try? await Task.sleep(for: .milliseconds(800))
            if let bible = state.bibles?.first {
                client.send(.presentBible(translation: bible.code, bookId: "JHN", chapter: 3, from: 16, to: 16))
            }
            return
        }
        guard let slide = value(of: "-show").flatMap(Int.init) else { return }
        for _ in 0..<100 {
            if let item = client.state?.items.first {
                client.send(.showSlide(id: item.id, slide: slide))
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
    #endif
}

#Preview {
    AppRoot()
}
