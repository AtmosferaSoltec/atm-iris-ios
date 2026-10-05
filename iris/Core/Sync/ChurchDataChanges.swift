//
//  ChurchDataChanges.swift
//  iris
//

import Foundation

/// Fan-out of "the local copy changed" so open screens reload silently.
final class ChurchDataChanges {
    private var subscribers: [UUID: (kinds: Set<EntityKind>, continuation: AsyncStream<Void>.Continuation)] = [:]

    /// Yields once per change that touches any of `kinds`, until the consuming task ends.
    func stream(for kinds: Set<EntityKind>) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers[id] = (kinds, continuation)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in self?.subscribers[id] = nil }
        }
        return stream
    }

    func publish(_ kinds: Set<EntityKind>) {
        guard !kinds.isEmpty else { return }
        for subscriber in subscribers.values where !subscriber.kinds.isDisjoint(with: kinds) {
            subscriber.continuation.yield()
        }
    }
}
