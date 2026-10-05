//
//  ConnectivityMonitor.swift
//  iris
//

import Foundation
import Network

/// Reports whether the device has a usable network path.
final class ConnectivityMonitor {
    private(set) var isConnected = true

    /// Yields the connection state on every change, starting with the current one.
    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.atmosfera.iris.connectivity"))
        }
        .removingDuplicates { [weak self] in self?.isConnected = $0 }
    }
}

private extension AsyncStream where Element == Bool {
    /// Drops repeated values and reports each new one to `onChange` first.
    func removingDuplicates(onChange: @escaping (Bool) -> Void) -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                var last: Bool?
                for await value in self where value != last {
                    last = value
                    onChange(value)
                    continuation.yield(value)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
