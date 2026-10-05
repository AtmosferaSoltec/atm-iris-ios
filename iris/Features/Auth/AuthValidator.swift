//
//  AuthValidator.swift
//  iris
//

import Foundation

/// Pure validation rules for auth forms. Returns a user-facing message or `nil` when valid.
nonisolated struct AuthValidator {
    static let minimumPasswordLength = 8

    func emailError(for email: String) -> String? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return String(localized: "Ingresa el correo de tu iglesia.")
        }
        if value.wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]{2,}/) == nil {
            return String(localized: "Ese correo no parece válido.")
        }
        return nil
    }

    func passwordError(for password: String, requiresStrength: Bool) -> String? {
        if password.isEmpty {
            return String(localized: "Ingresa tu contraseña.")
        }
        if requiresStrength && password.count < Self.minimumPasswordLength {
            return String(localized: "Usa al menos \(Self.minimumPasswordLength) caracteres.")
        }
        return nil
    }

    func requiredError(for value: String, message: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? message : nil
    }
}
