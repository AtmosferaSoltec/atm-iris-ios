//
//  RemoteClient.swift
//  iris
//

import Foundation
import Network
import Observation
import UIKit

/// The iPad's whole connection to Iris on the computer: finds it, pairs with the code, keeps the latest state and
/// sends commands. Nothing is written to disk: the session token lives here, in memory, and dies with the app.
@Observable
final class RemoteClient {
    enum Phase: Equatable {
        case disconnected
        /// Looking for the computer and trying the code.
        case connecting
        case connected
        /// The link dropped while the app stays open: trying again with the token, without asking for the code.
        case reconnecting
    }

    private(set) var phase: Phase = .disconnected
    private(set) var state: RemoteState?
    /// Paired, and the computer said it is away from the service screen (as opposed to "still loading").
    private(set) var isConsoleAway = false
    /// When `state` arrived: seconds, the block's clock and the countdown keep moving from this moment.
    private(set) var stateReceivedAt = Date()
    private(set) var computerName: String?
    /// Why the last attempt failed, in Spanish, for the pairing screen.
    private(set) var failureMessage: String?
    /// The computer answered and refused the code: the digits typed are wrong, so the screen clears them.
    /// (Not finding the computer says nothing about the code, which stays for the next try.)
    private(set) var isCodeRejected = false

    private var token: String?
    private var url: URL?
    private var link: RemoteLink?
    private var attempt: Task<Void, Never>?
    private var pending: [String: CheckedContinuation<RemoteResponse, Error>] = [:]
    private var nextRequestId = 0

    /// Pictures of images and videos, made by the computer from its files. Memory only, gone on disconnect.
    private(set) var thumbnails: [String: UIImage] = [:]
    private var thumbnailQueue: [String] = []
    private var thumbnailMisses: Set<String> = []
    private var isLoadingThumbnails = false

    init() {}

    /// Sample content for previews and screenshots (`-demo`): a connected client that talks to no one.
    init(demo: RemoteState, computerName: String) {
        state = demo
        self.computerName = computerName
        phase = .connected
    }

    // MARK: Pairing

    /// Looks for Iris on the network (or goes straight to `address`, "192.168.1.20" or "192.168.1.20:47831") and
    /// tries `code` on every computer it finds.
    func connect(code: String, address: String? = nil) {
        guard phase != .connecting else { return }
        attempt?.cancel()
        phase = .connecting
        failureMessage = nil
        isCodeRejected = false
        attempt = Task { [weak self] in
            let outcome = await Self.pair(code: code, address: address)
            guard let self, !Task.isCancelled else { return }
            switch outcome {
            case .paired(let link, let url, let token, let name):
                self.adopt(link: link, url: url, token: token, computerName: name)
            case .refused(let failure):
                self.isCodeRejected = true
                self.fail(failure.message)
            case .localNetworkDenied:
                self.fail("Iris no tiene permiso para usar la red local. Actívalo en Ajustes del iPad → Iris → Red local.")
            case .notFound:
                self.fail(address == nil
                    ? "No encontramos Iris. Revisa que la computadora y el iPad estén en la misma red Wi-Fi y que el control desde iPad esté encendido. En Windows, el firewall debe permitir Iris."
                    : "No pudimos conectar con esa dirección. Revisa que sea la de la computadora (aparece en Configuración → Control desde iPad) y que el firewall de Windows permita Iris.")
            }
        }
    }

    func disconnect() {
        failPending()
        attempt?.cancel()
        attempt = nil
        link?.close()
        link = nil
        token = nil
        url = nil
        state = nil
        computerName = nil
        thumbnails = [:]
        thumbnailMisses = []
        thumbnailQueue = []
        phase = .disconnected
    }

    /// Asks for a thumbnail once. One at a time: the computer draws each video's frame in turn, and a burst of
    /// twenty would run out the answer's timeout.
    func wantThumbnail(_ id: String) {
        guard thumbnails[id] == nil, !thumbnailMisses.contains(id), !thumbnailQueue.contains(id) else { return }
        thumbnailQueue.append(id)
        guard !isLoadingThumbnails else { return }
        isLoadingThumbnails = true
        Task { [weak self] in
            while let self, !self.thumbnailQueue.isEmpty {
                let next = self.thumbnailQueue.removeFirst()
                do {
                    let answer = try await self.request(["kind": "thumbnail", "id": next])
                    if let base64 = answer.image, let data = Data(base64Encoded: base64), let image = UIImage(data: data) {
                        self.thumbnails[next] = image
                    } else {
                        self.thumbnailMisses.insert(next)
                    }
                } catch {
                    // Offline: try again when the sheet shows it after reconnecting.
                    if self.phase != .connected { self.thumbnailQueue = []; break }
                    self.thumbnailMisses.insert(next)
                }
            }
            self?.isLoadingThumbnails = false
        }
    }

    /// Asks the computer something only it has (the Bible's books and verses) and waits for the answer.
    func request(_ question: [String: Any]) async throws -> RemoteResponse {
        guard phase == .connected, let link else { throw RemoteFailure(code: "OFFLINE", message: "Sin conexión con Iris.") }
        nextRequestId += 1
        let id = "r\(nextRequestId)"
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            link.send(["type": "request", "id": id, "request": question])
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                self?.pending.removeValue(forKey: id)?.resume(throwing: RemoteFailure(code: "TIMEOUT", message: "La computadora no respondió."))
            }
        }
    }

    private func failPending() {
        let waiting = pending
        pending = [:]
        for continuation in waiting.values {
            continuation.resume(throwing: RemoteFailure(code: "OFFLINE", message: "Se perdió la conexión con Iris."))
        }
    }

    func send(_ command: RemoteCommand) {
        guard phase == .connected else { return }
        link?.send(["type": "command", "command": command.json])
    }

    // MARK: Time that moves on its own

    /// Seconds played at `date`: the computer only tells us again when something changes.
    func position(of playback: RemoteState.Playback, at date: Date) -> Double {
        guard playback.isPlaying else { return playback.position }
        let elapsed = playback.position + date.timeIntervalSince(stateReceivedAt)
        return playback.duration > 0 ? min(elapsed, playback.duration) : elapsed
    }

    func remaining(of countdown: RemoteState.Countdown, at date: Date) -> Double {
        guard countdown.isRunning else { return countdown.remainingSeconds }
        return max(0, countdown.remainingSeconds - date.timeIntervalSince(stateReceivedAt))
    }

    func elapsed(of service: RemoteState.Service, at date: Date) -> Double {
        guard service.phase == .running else { return service.elapsedSeconds }
        return service.elapsedSeconds + date.timeIntervalSince(stateReceivedAt)
    }

    // MARK: Session

    private func adopt(link: RemoteLink, url: URL, token: String, computerName: String) {
        self.link?.close()
        self.link = link
        self.url = url
        self.token = token
        self.computerName = computerName
        phase = .connected
        link.handler = { [weak self] event in self?.receive(event, from: link) }
    }

    private func receive(_ event: RemoteLink.Event, from source: RemoteLink) {
        guard source === link else { return }
        switch event {
        case .message(.state(let next)):
            state = next
            isConsoleAway = next == nil
            stateReceivedAt = Date()
        case .message(.response(let id, let response)):
            guard let continuation = pending.removeValue(forKey: id) else { return }
            if let error = response.error {
                continuation.resume(throwing: RemoteFailure(code: "REQUEST", message: error))
            } else {
                continuation.resume(returning: response)
            }
        case .message(.bye(let reason)):
            disconnect()
            failureMessage = reason == "disabled"
                ? "El control desde iPad se apagó en la computadora."
                : "La computadora desconectó este iPad."
        case .closed:
            reconnect()
        default:
            break
        }
    }

    /// The Wi-Fi blinked or the iPad slept: the token we hold is enough to come back without the code.
    private func reconnect() {
        guard let url, let token, phase == .connected else { return }
        failPending()
        phase = .reconnecting
        link?.close()
        link = nil
        attempt = Task { [weak self] in
            for _ in 0..<10 {
                guard !Task.isCancelled else { return }
                let outcome = await Self.handshake(
                    url: url,
                    greeting: ["type": "resume", "protocol": RemoteProtocol.version, "token": token]
                )
                guard let self, !Task.isCancelled else { return }
                switch outcome {
                case .paired(let link, let url, let token, let name):
                    self.adopt(link: link, url: url, token: token, computerName: name)
                    return
                case .refused:
                    self.disconnect()
                    self.failureMessage = "Se perdió la conexión. Escribe el código otra vez."
                    return
                case .notFound, .localNetworkDenied:
                    try? await Task.sleep(for: .seconds(2))
                }
            }
            self?.disconnect()
            self?.failureMessage = "Se perdió la conexión con Iris."
        }
    }

    private func fail(_ message: String) {
        phase = .disconnected
        failureMessage = message
    }

    // MARK: Finding and greeting the computer

    private enum Outcome {
        case paired(RemoteLink, URL, token: String, computerName: String)
        case refused(RemoteFailure)
        case localNetworkDenied
        case notFound
    }

    /// Tries the code on every computer announcing Iris (or the typed address), all at once. The first that accepts
    /// wins; a refusal waits a few seconds in case another computer is the right one.
    private static func pair(code: String, address: String?) async -> Outcome {
        let greeting: [String: Any] = ["type": "pair", "protocol": RemoteProtocol.version, "code": code]
        if let address, let url = url(forAddress: address) {
            return await handshake(url: url, greeting: greeting)
        }
        return await withCheckedContinuation { continuation in
            let browser = NWBrowser(for: .bonjour(type: RemoteProtocol.serviceType, domain: nil), using: .tcp)
            var isDone = false
            var refusal: RemoteFailure?
            var isDenied = false

            func finish(_ outcome: Outcome) {
                guard !isDone else { return }
                isDone = true
                browser.cancel()
                continuation.resume(returning: outcome)
            }
            func finishWithWhatWeKnow() {
                if let refusal { finish(.refused(refusal)) }
                else { finish(isDenied ? .localNetworkDenied : .notFound) }
            }

            browser.stateUpdateHandler = { state in
                // The person said no to "red local" (or never saw the question): nothing will ever be found.
                if case .waiting(let error) = state, isPolicyDenied(error) { isDenied = true }
                if case .failed(let error) = state, isPolicyDenied(error) { isDenied = true; finishWithWhatWeKnow() }
            }
            browser.browseResultsChangedHandler = { _, changes in
                for case .added(let result) in changes where !isDone {
                    Task {
                        var outcome = Outcome.notFound
                        if let url = await resolve(result.endpoint) {
                            outcome = await handshake(url: url, greeting: greeting)
                        }
                        if isDone {
                            if case .paired(let link, _, _, _) = outcome { link.close() }
                            return
                        }
                        switch outcome {
                        case .paired:
                            finish(outcome)
                        case .refused(let failure):
                            refusal = failure
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { finishWithWhatWeKnow() }
                        default:
                            break
                        }
                    }
                }
            }
            browser.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { finishWithWhatWeKnow() }
        }
    }

    /// Opens a socket, says hello, and waits for the answer (twenty seconds at most: the first time, iOS asks for the local network permission meanwhile).
    private static func handshake(url: URL, greeting: [String: Any]) async -> Outcome {
        await withCheckedContinuation { continuation in
            let link = RemoteLink(url: url)
            var isDone = false
            func finish(_ outcome: Outcome) {
                guard !isDone else { return }
                isDone = true
                if case .paired = outcome {
                    // Later messages (the state comes right behind) wait for the session to take over.
                    link.handler = nil
                } else {
                    link.close()
                }
                continuation.resume(returning: outcome)
            }
            link.handler = { event in
                switch event {
                case .ready:
                    link.send(greeting)
                case .message(.paired(let token, let name)):
                    finish(.paired(link, url, token: token, computerName: name))
                case .message(.error(let failure)):
                    finish(.refused(failure))
                case .closed:
                    finish(.notFound)
                case .message:
                    break
                }
            }
            link.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { finish(.notFound) }
        }
    }

    private static func isPolicyDenied(_ error: NWError) -> Bool {
        if case .dns(let code) = error { return code == -65570 } // kDNSServiceErr_PolicyDenied
        return false
    }

    private static func url(forAddress address: String) -> URL? {
        let parts = address.trimmingCharacters(in: .whitespaces).split(separator: ":", maxSplits: 1)
        guard let host = parts.first, !host.isEmpty else { return nil }
        let port = parts.count > 1 ? UInt16(parts[1]) : RemoteProtocol.defaultPort
        guard let port else { return nil }
        return URL(string: "ws://\(host):\(port)/remote")
    }

    /// A Bonjour service has a name, not an address: connect once to learn the IPv4 address behind it.
    private static func resolve(_ endpoint: NWEndpoint) async -> URL? {
        await withCheckedContinuation { continuation in
            let parameters = NWParameters.tcp
            (parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options)?.version = .v4
            let probe = NWConnection(to: endpoint, using: parameters)
            var isDone = false
            func finish(_ url: URL?) {
                guard !isDone else { return }
                isDone = true
                probe.cancel()
                continuation.resume(returning: url)
            }
            probe.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if case .hostPort(let host, let port)? = probe.currentPath?.remoteEndpoint,
                       case .ipv4(let address) = host {
                        // The interface suffix ("%en0") only belongs to link-local addresses.
                        let text = "\(address)".split(separator: "%").first.map(String.init) ?? "\(address)"
                        finish(URL(string: "ws://\(text):\(port.rawValue)/remote"))
                    } else {
                        finish(nil)
                    }
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            probe.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { finish(nil) }
        }
    }
}
