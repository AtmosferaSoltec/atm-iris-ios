//
//  PasswordRecoveryViewModel.swift
//  iris
//

import Foundation
import Observation

@Observable
final class PasswordRecoveryViewModel: Identifiable {
    enum Phase: Equatable {
        case editing, sending, sent
    }

    var email: String {
        didSet { if error != nil { error = nil } }
    }

    private(set) var phase: Phase = .editing
    private(set) var error: String?

    private let authService: any AuthService
    private let validator = AuthValidator()

    init(email: String, authService: any AuthService) {
        self.email = email
        self.authService = authService
    }

    var isSending: Bool { phase == .sending }

    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func send() async {
        guard phase == .editing else { return }
        if let message = validator.emailError(for: email) {
            error = message
            return
        }

        phase = .sending
        do {
            try await authService.requestPasswordReset(email: trimmedEmail)
            phase = .sent
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "No pudimos enviar el enlace. Inténtalo de nuevo.")
            phase = .editing
        }
    }
}
