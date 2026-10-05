//
//  PasswordRecoveryViewModel.swift
//  iris
//

import Foundation
import Observation

/// Password recovery with an emailed 6-digit code: email → code → new password.
@Observable
final class PasswordRecoveryViewModel: Identifiable {
    enum Phase: Equatable {
        case email, code, newPassword, done
    }

    enum Field: Hashable {
        case email, code, password, confirmation
    }

    static let codeLength = 6
    static let resendDelay = 60

    // MARK: State

    private(set) var phase: Phase = .email
    var email: String { didSet { clearError(.email) } }
    var code = "" {
        didSet {
            let digits = String(code.filter(\.isNumber).prefix(Self.codeLength))
            if digits != code { code = digits }
            clearError(.code)
        }
    }
    var password = "" { didSet { clearError(.password) } }
    var confirmation = "" { didSet { clearError(.confirmation) } }

    private(set) var errors: [Field: String] = [:]
    /// Problems that belong to no field (network, rate limit).
    private(set) var bannerMessage: String?
    private(set) var isWorking = false
    /// Seconds until "Reenviar código" works again.
    private(set) var resendCountdown = 0

    private let authService: any AuthService
    private let validator = AuthValidator()
    private let onCompleted: () -> Void
    private var countdownTask: Task<Void, Never>?

    init(email: String, authService: any AuthService, onCompleted: @escaping () -> Void = {}) {
        self.email = email
        self.authService = authService
        self.onCompleted = onCompleted
    }

    // MARK: Presentation

    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// 1, 2 or 3.
    var stepNumber: Int {
        switch phase {
        case .email: 1
        case .code: 2
        case .newPassword, .done: 3
        }
    }

    var canResend: Bool { resendCountdown == 0 && !isWorking }

    func error(for field: Field) -> String? { errors[field] }

    // MARK: Intents

    /// Step 1: always moves on, the API never says whether the account exists.
    func sendCode() async {
        guard phase == .email, !isWorking else { return }
        if let message = validator.emailError(for: email) {
            errors[.email] = message
            return
        }
        await run {
            try await self.authService.requestPasswordReset(email: self.trimmedEmail)
            self.phase = .code
            self.startResendCountdown()
        } onError: { error in
            self.errors[.email] = error.fieldErrors["email"]
            if self.errors[.email] == nil { self.bannerMessage = error.localizedDescription }
        }
    }

    func resendCode() async {
        guard phase == .code, canResend else { return }
        code = ""
        await run {
            try await self.authService.requestPasswordReset(email: self.trimmedEmail)
            self.startResendCountdown()
        } onError: { error in
            self.bannerMessage = error.localizedDescription
        }
    }

    /// Step 2: checks the code before asking for the new password.
    func verifyCode() async {
        guard phase == .code, !isWorking else { return }
        guard code.count == Self.codeLength else {
            errors[.code] = String(localized: "Escribe los \(Self.codeLength) dígitos del código.")
            return
        }
        await run {
            try await self.authService.verifyResetCode(email: self.trimmedEmail, code: self.code)
            self.phase = .newPassword
        } onError: { error in
            if case .network = error {
                self.bannerMessage = error.localizedDescription
            } else {
                self.errors[.code] = error.fieldErrors["code"] ?? error.localizedDescription
            }
        }
    }

    /// Step 3: saves the new password. Success closes the modal and tells the sign-in screen.
    func savePassword() async {
        guard phase == .newPassword, !isWorking else { return }
        var errors: [Field: String] = [:]
        errors[.password] = validator.passwordError(for: password, requiresStrength: true)
        if errors[.password] == nil, confirmation != password {
            errors[.confirmation] = String(localized: "Las contraseñas no coinciden.")
        }
        self.errors = errors
        guard errors.isEmpty else { return }

        await run {
            try await self.authService.resetPassword(email: self.trimmedEmail, code: self.code, password: self.password, confirmation: self.confirmation)
            self.password = ""
            self.confirmation = ""
            self.phase = .done
            self.onCompleted()
        } onError: { error in
            self.errors[.password] = error.fieldErrors["password"]
            self.errors[.confirmation] = error.fieldErrors["passwordConfirmation"]
            if self.errors.isEmpty { self.bannerMessage = error.localizedDescription }
        }
    }

    /// Back from the code step to fix the email.
    func editEmail() {
        guard phase == .code else { return }
        countdownTask?.cancel()
        resendCountdown = 0
        code = ""
        phase = .email
    }

    /// Installs a phase directly. Used by previews.
    func apply(phase: Phase, code: String = "", resendCountdown: Int = 0) {
        self.phase = phase
        self.code = code
        self.resendCountdown = resendCountdown
    }

    // MARK: Private

    private func run(_ work: @escaping () async throws -> Void, onError: @escaping (AuthError) -> Void) async {
        isWorking = true
        bannerMessage = nil
        do {
            try await work()
        } catch {
            onError(AuthError(error))
        }
        isWorking = false
    }

    private func startResendCountdown() {
        countdownTask?.cancel()
        resendCountdown = Self.resendDelay
        countdownTask = Task { [weak self] in
            while let self, self.resendCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.resendCountdown -= 1
            }
        }
    }

    private func clearError(_ field: Field) {
        if errors[field] != nil { errors[field] = nil }
        if bannerMessage != nil { bannerMessage = nil }
    }
}

extension PasswordRecoveryViewModel {
    static func preview(_ phase: Phase) -> PasswordRecoveryViewModel {
        let viewModel = PasswordRecoveryViewModel(email: "pastor@vidanueva.org", authService: MockAuthService())
        viewModel.apply(phase: phase, code: phase == .code ? "4821" : "", resendCountdown: phase == .code ? 42 : 0)
        return viewModel
    }
}
