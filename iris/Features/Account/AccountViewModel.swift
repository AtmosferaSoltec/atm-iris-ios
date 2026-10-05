//
//  AccountViewModel.swift
//  iris
//

import Foundation
import Observation

/// The account menu of the top bar: who is signed in, switching church and signing out.
/// The team itself is managed on the web.
@Observable
final class AccountViewModel {
    enum Confirmation: Identifiable, Equatable {
        /// Signing out with writes still queued.
        case signOut(pending: Int)
        case signOutAll
        case switchChurch(UserSession.ChurchSummary, pending: Int)

        var id: String {
            switch self {
            case .signOut: "signOut"
            case .signOutAll: "signOutAll"
            case let .switchChurch(church, _): "switch-\(church.id)"
            }
        }
    }

    var confirmation: Confirmation?
    private(set) var isWorking = false
    var errorMessage: String?

    let context: SessionContext
    private let authService: any AuthService
    private let sync: any SyncService
    /// Leaves the signed-in experience.
    private let onSignedOut: () -> Void
    /// Enters another church's session.
    private let onSwitched: (UserSession) -> Void

    init(
        context: SessionContext,
        authService: any AuthService,
        sync: any SyncService,
        onSignedOut: @escaping () -> Void,
        onSwitched: @escaping (UserSession) -> Void
    ) {
        self.context = context
        self.authService = authService
        self.sync = sync
        self.onSignedOut = onSignedOut
        self.onSwitched = onSwitched
    }

    // MARK: Presentation

    var session: UserSession { context.session }

    var initials: String { session.churchInitials }

    var roleName: String { session.role.displayName }

    var canSwitchChurch: Bool { session.churches.count > 1 }

    var otherChurches: [UserSession.ChurchSummary] {
        session.churches.filter { $0.id != session.church.id }
    }

    var isConfirming: Bool {
        get { confirmation != nil }
        set { if !newValue { confirmation = nil } }
    }

    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    /// "Hay 3 cambios sin enviar. Si sigues, se perderán."
    func pendingWarning(_ pending: Int) -> String {
        pending == 1
            ? String(localized: "Hay 1 cambio sin enviar. Si sigues, se perderá.")
            : String(localized: "Hay \(pending) cambios sin enviar. Si sigues, se perderán.")
    }

    // MARK: Intents

    func requestSignOut() {
        let pending = sync.pendingCount
        if pending > 0 {
            confirmation = .signOut(pending: pending)
        } else {
            Task { await signOut() }
        }
    }

    func requestSignOutAll() {
        confirmation = .signOutAll
    }

    func requestSwitch(to church: UserSession.ChurchSummary) {
        guard church.id != session.church.id else { return }
        let pending = sync.pendingCount
        if pending > 0 {
            confirmation = .switchChurch(church, pending: pending)
        } else {
            Task { await switchChurch(to: church) }
        }
    }

    func confirm() async {
        guard let confirmation else { return }
        self.confirmation = nil
        switch confirmation {
        case .signOut: await signOut()
        case .signOutAll: await signOutAll()
        case let .switchChurch(church, _): await switchChurch(to: church)
        }
    }

    // MARK: Private

    private func signOut() async {
        isWorking = true
        await authService.signOut()
        await sync.discardLocalData()
        isWorking = false
        onSignedOut()
    }

    private func signOutAll() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await authService.signOutAll()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "Algo salió mal. Inténtalo de nuevo.")
            return
        }
        await sync.discardLocalData()
        onSignedOut()
    }

    /// The new church's copy replaces this one when its screens start.
    private func switchChurch(to church: UserSession.ChurchSummary) async {
        isWorking = true
        defer { isWorking = false }
        do {
            onSwitched(try await authService.switchChurch(to: church.id))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
    }
}

extension AccountViewModel {
    static func preview(role: UserSession.Role = .owner, churches: Int = 1, sync: any SyncService = MockSyncService()) -> AccountViewModel {
        var session = UserSession.preview(role: role)
        if churches > 1 {
            session.churches += [
                UserSession.ChurchSummary(id: UUID(), name: "Iglesia Bautista Central", role: .operator),
                UserSession.ChurchSummary(id: UUID(), name: "Misión Esperanza", role: .admin)
            ].prefix(churches - 1)
        }
        return AccountViewModel(
            context: SessionContext(session),
            authService: MockAuthService(),
            sync: sync,
            onSignedOut: {},
            onSwitched: { _ in }
        )
    }
}
