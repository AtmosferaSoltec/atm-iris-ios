//
//  SessionContext.swift
//  iris
//

import Foundation
import Observation

/// The signed-in session as screens read it. Stays current when the role or permissions change
/// (a refresh, `GET /auth/me`) without rebuilding the screens, so a running service is never lost.
@Observable
final class SessionContext {
    var session: UserSession

    init(_ session: UserSession) {
        self.session = session
    }

    func can(_ permission: Permission) -> Bool {
        session.can(permission)
    }

    static var preview: SessionContext { preview(role: .owner) }

    static func preview(role: UserSession.Role) -> SessionContext {
        SessionContext(.preview(role: role))
    }
}
