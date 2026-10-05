//
//  SessionStore.swift
//  iris
//

import Foundation
import Observation

/// App-wide source of truth for the signed-in account.
@Observable
final class SessionStore {
    private(set) var session: UserSession?

    func begin(_ session: UserSession) {
        self.session = session
    }

    func end() {
        session = nil
    }
}
