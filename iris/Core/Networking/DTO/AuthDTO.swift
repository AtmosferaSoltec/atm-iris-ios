//
//  AuthDTO.swift
//  iris
//
//  API contract §4 and §5.
//

import Foundation

nonisolated struct ClientInfoDTO: Codable, Hashable, Sendable {
    let platform: PlatformDTO
    let deviceName: String?
}

nonisolated struct ChurchSummaryDTO: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let role: RoleDTO
}

nonisolated struct SessionViewDTO: Codable, Hashable, Sendable {
    nonisolated struct User: Codable, Hashable, Sendable {
        let id: String
        let email: String
        let fullName: String
    }

    nonisolated struct Church: Codable, Hashable, Sendable {
        let id: String
        let name: String
        let timezone: String
    }

    nonisolated struct Session: Codable, Hashable, Sendable {
        let id: String
        let platform: PlatformDTO
        let deviceName: String?
    }

    let user: User
    let church: Church
    let role: RoleDTO
    let permissions: [String]
    let churches: [ChurchSummaryDTO]
    let session: Session
}

/// `SessionView & tokens`.
nonisolated struct AuthResultDTO: Codable, Hashable, Sendable {
    let user: SessionViewDTO.User
    let church: SessionViewDTO.Church
    let role: RoleDTO
    let permissions: [String]
    let churches: [ChurchSummaryDTO]
    let session: SessionViewDTO.Session
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date

    var sessionView: SessionViewDTO {
        SessionViewDTO(user: user, church: church, role: role, permissions: permissions, churches: churches, session: session)
    }
}

nonisolated struct DeviceSessionDTO: Codable, Hashable, Sendable {
    let id: String
    let platform: PlatformDTO
    let deviceName: String?
    let createdAt: Date
    let lastUsedAt: Date
    let ipAddress: String?
    let isCurrent: Bool
}

// MARK: Requests

nonisolated struct SignInBody: Encodable, Sendable {
    let email: String
    let password: String
    let client: ClientInfoDTO
}

nonisolated struct SignUpBody: Encodable, Sendable {
    let churchName: String
    let fullName: String
    let email: String
    let password: String
    let client: ClientInfoDTO
}

nonisolated struct RefreshBody: Encodable, Sendable {
    let refreshToken: String
}

nonisolated struct SwitchChurchBody: Encodable, Sendable {
    let churchId: String
}

nonisolated struct ForgotPasswordBody: Encodable, Sendable {
    let email: String
}

nonisolated struct VerifyResetCodeBody: Encodable, Sendable {
    let email: String
    let code: String
}

nonisolated struct VerifyResetCodeDTO: Codable, Hashable, Sendable {
    let valid: Bool
}

nonisolated struct ResetPasswordBody: Encodable, Sendable {
    let email: String
    let code: String
    let password: String
    let passwordConfirmation: String
}
