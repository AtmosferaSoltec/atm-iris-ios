//
//  RemoteClient.swift
//  iris
//

import Foundation
import Observation
import UIKit

/// The iPad's whole connection to Iris on the computer: pairs using the QR's link, keeps the latest state and
/// sends commands. Nothing is written to disk: the session token lives here, in memory, and dies with the app.
@Observable
final class RemoteClient {
    enum Phase: Equatable {
        case disconnected
        /// Trying the addresses from the QR.
        case connecting
        case connected
        /// The link dropped while the app stays open: trying again with the token, without scanning again.
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

    /// Tries every address in the QR at once; the first that completes the handshake and accepts the secret wins.
    func connect(link: PairingLink) {
        guard phase != .connecting else { return }
        attempt?.cancel()
        phase = .connecting
        failureMessage = nil
        attempt = Task { [weak self] in
            let outcome = await Self.pair(link: link)
            guard let self, !Task.isCancelled else {
                if case .paired(let link, _, _, _) = outcome { link.close() }
                return
            }
            switch outcome {
            case .paired(let socket, let url, let token, let name):
                self.adopt(link: socket, url: url, token: token, computerName: link.computerName ?? name)
            case .refused(let failure):
                self.fail(failure.message)
            case .notFound:
                self.fail("No pudimos conectar. Revisa que el iPad y la computadora estén en la misma red Wi‑Fi.")
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
                    self.failureMessage = "Se perdió la conexión. Escanea el código QR otra vez."
                    return
                case .notFound:
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
        case notFound
    }

    /// Seconds one address gets to answer. The computer may have several interfaces and only one is on this Wi-Fi.
    private static let addressTimeout = 4.0

    /// Finds which of the QR's addresses answers, then pairs over that one only (two rounds: the first time, iOS
    /// asks for the local network permission while the first round waits, and the second goes through once it is
    /// granted). The secret is single-use, so it is never sent down several addresses at once: the computer may
    /// have more than one (cable, virtual adapters), all of them the same Iris.
    private static func pair(link: PairingLink) async -> Outcome {
        let greeting: [String: Any] = ["type": "pair", "protocol": RemoteProtocol.version, "code": link.secret]
        for _ in 0..<2 {
            if let url = await reach(urls: link.urls) {
                switch await handshake(url: url, greeting: greeting) {
                case .paired(let socket, let url, let token, let name):
                    return .paired(socket, url, token: token, computerName: name)
                case .refused(let failure):
                    // The computer's answer about the secret: asking again with it cannot change that.
                    return .refused(failure)
                case .notFound:
                    break
                }
            }
            if Task.isCancelled { break }
        }
        return .notFound
    }

    /// The first address whose socket opens (nothing is said on it), or nil when none does in time.
    private static func reach(urls: [URL]) async -> URL? {
        guard !urls.isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            var isDone = false
            var remaining = urls.count
            var probes: [RemoteLink] = []
            func finish(_ winner: URL?) {
                guard !isDone else { return }
                isDone = true
                probes.forEach { $0.close() }
                continuation.resume(returning: winner)
            }
            for url in urls {
                let probe = RemoteLink(url: url)
                probes.append(probe)
                probe.handler = { event in
                    switch event {
                    case .ready:
                        finish(url)
                    case .closed:
                        remaining -= 1
                        if remaining == 0 { finish(nil) }
                    case .message:
                        break
                    }
                }
                probe.start()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + addressTimeout) { finish(nil) }
        }
    }

    /// Opens a socket, says hello, and waits for the answer (`timeout` seconds at most).
    private static func handshake(url: URL, greeting: [String: Any], timeout: Double = 8) async -> Outcome {
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
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish(.notFound) }
        }
    }
}
