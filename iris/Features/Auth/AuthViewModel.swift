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
    /// Errors are red; notices such as "Tu contraseña quedó actualizada" are green.
    private(set) var bannerStyle: IrisBanner.Style = .error
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
                        fullName: trimmed(leaderName),
                        email: trimmed(signUpEmail),
                        password: signUpPassword
                    )
                )
            }
            signInPassword = ""
            signUpPassword = ""
            onAuthenticated(session)
        } catch {
            show(AuthError(error))
        }
    }

    func presentPasswordRecovery() {
        recoveryViewModel = PasswordRecoveryViewModel(email: trimmed(signInEmail), authService: authService) { [weak self] in
            self?.showNotice(String(localized: "Tu contraseña quedó actualizada. Inicia sesión con la nueva."), style: .success)
        }
    }

    /// Explains why the app came back to the sign-in screen.
    func presentSignOut(reason: SignOutReason) {
        guard reason == .expired else { return }
        mode = .signIn
        showNotice(String(localized: "Tu sesión expiró. Vuelve a iniciar sesión."), style: .error)
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
            errors[.signInEmail] = validator.emailError(for: signInEmail)
            errors[.signInPassword] = validator.passwordError(for: signInPassword, requiresStrength: false)
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

    /// API field errors go under their field; anything else goes to the banner.
    private func show(_ error: AuthError) {
        var errors: [Field: String] = [:]
        for (key, message) in error.fieldErrors {
            if let field = field(forAPIKey: key) { errors[field] = message }
        }
        fieldErrors = errors
        focusRequest = fieldOrder.first { errors[$0] != nil }
        if errors.isEmpty {
            showNotice(error.errorDescription ?? String(localized: "Algo salió mal. Inténtalo de nuevo."), style: .error)
        }
    }

    private func field(forAPIKey key: String) -> Field? {
        switch (mode, key) {
        case (.signIn, "email"): .signInEmail
        case (.signIn, "password"): .signInPassword
        case (.signUp, "churchName"): .churchName
        case (.signUp, "fullName"): .leaderName
        case (.signUp, "email"): .signUpEmail
        case (.signUp, "password"): .signUpPassword
        default: nil
        }
    }

    private func showNotice(_ message: String, style: IrisBanner.Style) {
        bannerStyle = style
        bannerMessage = message
    }

    private func clearFeedback(for field: Field) {
        if fieldErrors[field] != nil { fieldErrors[field] = nil }
        if bannerMessage != nil { bannerMessage = nil }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
