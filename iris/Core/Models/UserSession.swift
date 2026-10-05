//
//  UserSession.swift
//  iris
//

import Foundation

/// An authenticated church account.
nonisolated struct UserSession: Identifiable, Equatable, Sendable {
    let id: UUID
    let churchName: String
    let leaderName: String
    let email: String
}

nonisolated struct SignInCredentials: Equatable, Sendable {
    let email: String
    let password: String
}

nonisolated struct SignUpRequest: Equatable, Sendable {
    let churchName: String
    let leaderName: String
    let email: String
    let password: String
}
