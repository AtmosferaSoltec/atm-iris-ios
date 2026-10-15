//
//  AuthViewModel.swift
//  iris
//

import Foundation
import Observation

@Observable
final class AuthViewModel {
    enum Field: Hashable {
        case signInEmail, signInPassword
    }

    // MARK: State

    var signInEmail = "" { didSet { clearFeedback(for: .signInEmail) } }
    var signInPassword = "" { didSet { clearFeedback(for: .signInPassword) } }

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

    var headline: LocalizedStringResource { "Te damos la bienvenida" }

    var subtitle: LocalizedStringResource { "Ingresa con el correo de tu iglesia para preparar el servicio." }

    var submitTitle: LocalizedStringResource { "Entrar" }

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
            let session = try await authService.signIn(
                SignInCredentials(email: trimmed(signInEmail), password: signInPassword)
            )
            signInPassword = ""
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
        errors[.signInEmail] = validator.emailError(for: signInEmail)
        errors[.signInPassword] = validator.passwordError(for: signInPassword, requiresStrength: false)

        fieldErrors = errors
        focusRequest = fieldOrder.first { errors[$0] != nil }
        return errors.isEmpty
    }

    private let fieldOrder: [Field] = [.signInEmail, .signInPassword]

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
        switch key {
        case "email": .signInEmail
        case "password": .signInPassword
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
