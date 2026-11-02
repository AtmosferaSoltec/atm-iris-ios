//
//  RemoteLink.swift
//  iris
//

import Foundation
import Network

/// One WebSocket to one computer, over the local network (plain `ws`, no TLS: it never leaves the Wi-Fi).
/// Everything runs on the main queue so the rest of the app never thinks about threads.
final class RemoteLink {
    enum Event {
        case ready
        case message(ServerMessage)
        case closed
    }

    private let connection: NWConnection
    private var backlog: [Event] = []
    private var isClosed = false

    /// Events that arrive while nobody listens are kept and handed over as soon as someone does.
    var handler: ((Event) -> Void)? {
        didSet {
            guard let handler else { return }
            let pending = backlog
            backlog = []
            pending.forEach(handler)
        }
    }

    /// `url` is `ws://host:port/remote`: the WebSocket client needs the address and path to say hello.
    init(url: URL) {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 10
        let parameters = NWParameters(tls: nil, tcp: tcp)
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        webSocket.maximumMessageSize = 2_000_000
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        connection = NWConnection(to: .url(url), using: parameters)
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.emit(.ready)
                self?.receive()
            case .failed, .cancelled:
                self?.finish()
            default:
                // `.waiting` is also where iOS holds the connection while the person answers the
                // "red local" permission: the handshake's own timeout decides when to give up.
                break
            }
        }
        connection.start(queue: .main)
    }

    func send(_ message: [String: Any]) {
        guard !isClosed, let data = try? JSONSerialization.data(withJSONObject: message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "iris", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        handler = nil
        connection.cancel()
    }

    private func receive() {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self, !self.isClosed else { return }
            if error != nil {
                self.finish()
                return
            }
            let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                as? NWProtocolWebSocket.Metadata
            switch metadata?.opcode {
            case .text:
                if let data, let message = try? JSONDecoder().decode(ServerMessage.self, from: data) {
                    self.emit(.message(message))
                }
            case .close:
                self.finish()
                return
            default:
                break
            }
            self.receive()
        }
    }

    private func finish() {
        guard !isClosed else { return }
        isClosed = true
        connection.cancel()
        emit(.closed)
        handler = nil
    }

    private func emit(_ event: Event) {
        if let handler { handler(event) } else { backlog.append(event) }
    }
}
