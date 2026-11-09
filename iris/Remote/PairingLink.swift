//
//  PairingLink.swift
//  iris
//

import Foundation

/// What the QR on the computer says: `iris://pair?v=1&c=<secret>&p=<port>&n=<name>&h=<ipv4>&h=<ipv4>...`.
/// Pure parsing, no network: `RemoteClient` decides how to reach the hosts.
struct PairingLink: Equatable {
    /// One-time secret; it travels in the `pair` message's `code` field.
    let secret: String
    let port: UInt16
    let computerName: String?
    /// Every IPv4 address of the computer, in the order the QR lists them.
    let hosts: [String]

    enum Failure: Error, Equatable {
        /// Not an `iris://pair` URL (some other QR).
        case notIris
        /// An Iris QR from another protocol version.
        case unsupportedVersion
        /// An Iris QR with missing or malformed fields.
        case malformed

        /// Spanish, ready for the screen.
        var message: String {
            switch self {
            case .notIris: "Ese no es el código QR de Iris. Escanea el que aparece en Iris en tu computadora."
            case .unsupportedVersion: "Actualiza Iris en la computadora o en el iPad."
            case .malformed: "El código QR de Iris está incompleto. Genera uno nuevo en la computadora."
            }
        }
    }

    static let supportedVersion = 1

    static func parse(_ text: String) -> Result<PairingLink, Failure> {
        guard let components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "iris",
              components.host?.lowercased() == "pair"
        else { return .failure(.notIris) }

        let items = components.queryItems ?? []
        func values(_ name: String) -> [String] { items.filter { $0.name == name }.compactMap(\.value) }

        guard let version = values("v").first.flatMap(Int.init) else { return .failure(.malformed) }
        guard version == supportedVersion else { return .failure(.unsupportedVersion) }

        guard let secret = values("c").first, !secret.isEmpty,
              let port = values("p").first.flatMap(UInt16.init), port > 0
        else { return .failure(.malformed) }

        let hosts = values("h")
        guard !hosts.isEmpty, hosts.allSatisfy(isIPv4) else { return .failure(.malformed) }

        let name = values("n").first.map { $0.trimmingCharacters(in: .whitespaces) }
        return .success(PairingLink(
            secret: secret,
            port: port,
            computerName: name?.isEmpty == false ? name : nil,
            hosts: hosts
        ))
    }

    /// `ws://<host>:<port>/remote` for each host.
    var urls: [URL] { hosts.compactMap { URL(string: "ws://\($0):\(port)/remote") } }

    /// Only dotted-quad addresses: anything else would let a crafted QR point the socket elsewhere.
    private static func isIPv4(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { !$0.isEmpty && $0.count <= 3 && $0.allSatisfy(\.isASCII) && UInt8($0) != nil }
    }
}
