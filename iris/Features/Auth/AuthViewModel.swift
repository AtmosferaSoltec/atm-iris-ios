//
//  AuthViewModel.swift
//  iris
//

import Foundation
import Observation

@Observable
final class AuthViewModel {
    enum Mode: Hashable, Identifiable, CaseIterable {
        case signIn, signUp

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .signIn: "Iniciar sesión"
            case .signUp: "Crear cuenta"
            }
        }
    }

    enum Field: Hashable {
        case signInEmail, signInPassword
        case churchName, leaderName, signUpEmail, signUpPassword
    }

    // MARK: State

    var mode: Mode = .signIn {
        didSet {
            guard oldValue != mode else { return }
            fieldErrors = [:]
            bannerMessage = nil
        }
    }

    var signInEmail = "" { didSet { clearFeedback(for: .signInEmail) } }
    var signInPassword = "" { didSet { clearFeedback(for: .signInPassword) } }

    var churchName = "" { didSet { clearFeedback(for: .churchName) } }
    var leaderName = "" { didSet { clearFeedback(for: .leaderName) } }
    var signUpEmail = "" { didSet { clearFeedback(for: .signUpEmail) } }
    var signUpPassword = "" { didSet { clearFeedback(for: .signUpPassword) } }

    private(set) var fieldErrors: [Field: String] = [:]
    private(set) var bannerMessage: String?
    private(set) var isSubmitting = false
    /// Field the view should focus after a failed validation.
    private(set) var focusRequest: Field?

    var recoveryViewModel: PasswordRecoveryViewModel?

    private(set) var showcaseItems: [ShowcaseItem]
    private(set) var showcaseIndex = 0

    // MARK: Dependencies

    private let authService: any AuthService
    private let validator = AuthValidator()
    private let onAuthenticated: (UserSession) -> Void

    init(
        authService: any AuthService,
        showcaseProvider: any ShowcaseContentProvider,
        onAuthenticated: @escaping (UserSession) -> Void
    ) {
        self.authService = authService
        self.showcaseItems = showcaseProvider.items()
        self.onAuthenticated = onAuthenticated
    }

    // MARK: Presentation

    var headline: LocalizedStringResource {
        switch mode {
        case .signIn: "Te damos la bienvenida"
        case .signUp: "Crea el espacio de tu iglesia"
        }
    }

    var subtitle: LocalizedStringResource {
        switch mode {
        case .signIn: "Ingresa con el correo de tu iglesia para preparar el servicio."
        case .signUp: "Configúralo en menos de un minuto y empieza a proyectar."
        }
    }

    var submitTitle: LocalizedStringResource {
        switch mode {
        case .signIn: "Entrar"
        case .signUp: "Crear cuenta"
        }
    }

    var currentShowcaseItem: ShowcaseItem? {
        showcaseItems.indices.contains(showcaseIndex) ? showcaseItems[showcaseIndex] : nil
    }

    func error(for field: Field) -> String? {
        fieldErrors[field]
    }

    // MARK: Intents

    func submit() async {
        guard !isSubmitting else { return }
        bannerMessage = nil
        guard validate() else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let session: UserSession
            switch mode {
            case .signIn:
                session = try await authService.signIn(
                    SignInCredentials(email: trimmed(signInEmail), password: signInPassword)
                )
            case .signUp:
                session = try await authService.signUp(
                    SignUpRequest(
                        churchName: trimmed(churchName),
                        leaderName: trimmed(leaderName),
                        email: trimmed(signUpEmail),
                        password: signUpPassword
                    )
                )
            }
            signInPassword = ""
            signUpPassword = ""
            onAuthenticated(session)
        } catch {
            bannerMessage = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Algo salió mal. Inténtalo de nuevo.")
        }
    }

    func presentPasswordRecovery() {
        recoveryViewModel = PasswordRecoveryViewModel(email: trimmed(signInEmail), authService: authService)
    }

    func focusRequestHandled() {
        focusRequest = nil
    }

    /// Rotates the showcase preview until the calling task is cancelled.
    func runShowcase() async {
        guard showcaseItems.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            showcaseIndex = (showcaseIndex + 1) % showcaseItems.count
        }
    }

    // MARK: Private

    private func validate() -> Bool {
        var errors: [Field: String] = [:]

        switch mode {
        case .signIn:
            // Mockup phase: sign-in is open so the rest of the app can be reviewed.
            // Restore email/password validation when the real API is connected.
            break
        case .signUp:
            errors[.churchName] = validator.requiredError(
                for: churchName, message: String(localized: "Escribe el nombre de tu iglesia.")
            )
            errors[.leaderName] = validator.requiredError(
                for: leaderName, message: String(localized: "Escribe el nombre del responsable.")
            )
            errors[.signUpEmail] = validator.emailError(for: signUpEmail)
            errors[.signUpPassword] = validator.passwordError(for: signUpPassword, requiresStrength: true)
        }

        fieldErrors = errors
        focusRequest = fieldOrder.first { errors[$0] != nil }
        return errors.isEmpty
    }

    private var fieldOrder: [Field] {
        switch mode {
        case .signIn: [.signInEmail, .signInPassword]
        case .signUp: [.churchName, .leaderName, .signUpEmail, .signUpPassword]
        }
    }

    private func clearFeedback(for field: Field) {
        if fieldErrors[field] != nil { fieldErrors[field] = nil }
        if bannerMessage != nil { bannerMessage = nil }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
