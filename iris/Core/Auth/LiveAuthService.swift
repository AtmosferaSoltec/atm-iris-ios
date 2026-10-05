//
//  LiveAuthService.swift
//  iris
//

import Foundation

/// `AuthService` over the API. Tokens and the saved session belong to `AuthSessionManager`.
struct LiveAuthService: AuthService {
    let manager: AuthSessionManager
    /// Client without tokens, for the public endpoints.
    let publicClient: APIClient
    /// Client with tokens, for the session endpoints.
    let client: APIClient
    /// `UIDevice.current.name`, sent as `client.deviceName`.
    let deviceName: String

    private var clientInfo: ClientInfoDTO {
        ClientInfoDTO(platform: .ios, deviceName: String(deviceName.prefix(80)))
    }

    func restoreSession() async -> UserSession? {
        await manager.restore()
    }

    func resumeSession() async {
        guard await manager.isSignedIn else { return }
        _ = await manager.refresh()
    }

    func sessionEvents() -> AsyncStream<SessionEvent> {
        manager.events
    }

    func signIn(_ credentials: SignInCredentials) async throws -> UserSession {
        try await authenticate(
            APIRequest(.post, "/auth/sign-in", body: SignInBody(email: credentials.email, password: credentials.password, client: clientInfo), requiresAuth: false)
        )
    }

    func signUp(_ request: SignUpRequest) async throws -> UserSession {
        try await authenticate(
            APIRequest(
                .post,
                "/auth/sign-up",
                body: SignUpBody(churchName: request.churchName, fullName: request.fullName, email: request.email, password: request.password, client: clientInfo),
                requiresAuth: false
            )
        )
    }

    func signOut() async {
        // Without network the API session stays open until it expires; the device forgets it anyway.
        try? await client.sendVoid(APIRequest(.post, "/auth/sign-out"))
        await manager.signOutLocally(reason: .requested)
    }

    func signOutAll() async throws {
        do {
            try await client.sendVoid(APIRequest(.post, "/auth/sign-out-all"))
        } catch APIError.unauthorized {
            // Already closed: nothing left to do on the API.
        } catch {
            throw AuthError(error)
        }
        await manager.signOutLocally(reason: .requested)
    }

    func switchChurch(to churchID: UUID) async throws -> UserSession {
        do {
            let result = try await client.send(
                APIRequest(.post, "/auth/switch-church", body: SwitchChurchBody(churchId: churchID.apiString)),
                as: AuthResultDTO.self
            )
            return try await manager.establish(result)
        } catch {
            throw AuthError(error)
        }
    }

    func reloadSession() async {
        guard let view = try? await client.send(APIRequest(.get, "/auth/me"), as: SessionViewDTO.self) else { return }
        try? await manager.update(view)
    }

    func requestPasswordReset(email: String) async throws {
        do {
            _ = try await publicClient.send(
                APIRequest(.post, "/auth/forgot-password", body: ForgotPasswordBody(email: email), requiresAuth: false),
                as: MessageDTO.self
            )
        } catch {
            throw AuthError(error)
        }
    }

    func verifyResetCode(email: String, code: String) async throws {
        do {
            _ = try await publicClient.send(
                APIRequest(.post, "/auth/verify-reset-code", body: VerifyResetCodeBody(email: email, code: code), requiresAuth: false),
                as: VerifyResetCodeDTO.self
            )
        } catch {
            throw AuthError(error)
        }
    }

    func resetPassword(email: String, code: String, password: String, confirmation: String) async throws {
        do {
            _ = try await publicClient.send(
                APIRequest(
                    .post,
                    "/auth/reset-password",
                    body: ResetPasswordBody(email: email, code: code, password: password, passwordConfirmation: confirmation),
                    requiresAuth: false
                ),
                as: MessageDTO.self
            )
        } catch {
            throw AuthError(error)
        }
    }

    // MARK: Private

    private func authenticate(_ request: @autoclosure () throws -> APIRequest) async throws -> UserSession {
        do {
            let result = try await publicClient.send(try request(), as: AuthResultDTO.self)
            return try await manager.establish(result)
        } catch {
            throw AuthError(error)
        }
    }
}
