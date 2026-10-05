//
//  UserSession.swift
//  iris
//

import Foundation

/// The signed-in account inside one church. Mirrors the API's `SessionView`, without tokens.
nonisolated struct UserSession: Identifiable, Hashable, Sendable {
    nonisolated enum Role: String, Hashable, Sendable {
        case owner, admin, `operator`

        var displayName: String {
            switch self {
            case .owner: String(localized: "Dueño")
            case .admin: String(localized: "Administrador")
            case .operator: String(localized: "Operador")
            }
        }
    }

    nonisolated enum Platform: String, Hashable, Sendable {
        case web, ios, windows
    }

    /// The church the session works in.
    nonisolated struct Church: Hashable, Sendable {
        let id: UUID
        var name: String
        var timeZone: TimeZone
    }

    /// Another church the account belongs to.
    nonisolated struct ChurchSummary: Identifiable, Hashable, Sendable {
        let id: UUID
        var name: String
        var role: Role
    }

    let userID: UUID
    var email: String
    var fullName: String
    var church: Church
    var role: Role
    var permissions: Set<Permission>
    /// Every active membership, sorted by name.
    var churches: [ChurchSummary]
    let sessionID: UUID
    var platform: Platform

    var id: UUID { sessionID }

    func can(_ permission: Permission) -> Bool {
        permissions.contains(permission)
    }

    /// Calendar for "today", schedules and periods: the church's time zone, not the iPad's.
    var calendar: Calendar { .church(timeZone: church.timeZone) }

    /// Initials of the first two words longer than two letters of the church name.
    var churchInitials: String {
        church.name
            .split(separator: " ")
            .filter { $0.count > 2 }
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

/// What a role may do (API contract §3). Clients decide with permissions, never with role names.
nonisolated enum Permission: String, Hashable, Sendable, CaseIterable {
    case churchManage = "church.manage"
    case modulesManage = "modules.manage"
    case membersManage = "members.manage"
    case songsManage = "songs.manage"
    case mediaManage = "media.manage"
    case serviceTypesManage = "serviceTypes.manage"
    case peopleManage = "people.manage"
    case recordsWrite = "records.write"
    case recordsManage = "records.manage"

    /// The permissions the API grants each role.
    static func granted(to role: UserSession.Role) -> Set<Permission> {
        switch role {
        case .owner, .admin: Set(allCases)
        case .operator: [.peopleManage, .recordsWrite]
        }
    }
}

nonisolated struct SignInCredentials: Equatable, Sendable {
    let email: String
    let password: String
}

nonisolated struct SignUpRequest: Equatable, Sendable {
    let churchName: String
    let fullName: String
    let email: String
    let password: String
}

nonisolated extension Calendar {
    /// Gregorian calendar in the church's time zone, with Spanish conventions.
    static func church(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "es")
        return calendar
    }
}

extension UserSession {
    /// Sample session for previews and tests.
    static var preview: UserSession { preview(role: .owner) }

    static func preview(role: Role) -> UserSession {
        let churchID = UUID(uuidString: "01A2C0DE-0000-7000-8000-000000000001") ?? UUID()
        return UserSession(
            userID: UUID(uuidString: "01A1C0DE-0000-7000-8000-000000000001") ?? UUID(),
            email: "pastor@vidanueva.org",
            fullName: "Daniel Ruiz",
            church: Church(id: churchID, name: "Iglesia Vida Nueva", timeZone: TimeZone(identifier: "America/Lima") ?? .current),
            role: role,
            permissions: Permission.granted(to: role),
            churches: [ChurchSummary(id: churchID, name: "Iglesia Vida Nueva", role: role)],
            sessionID: UUID(uuidString: "01A3C0DE-0000-7000-8000-000000000001") ?? UUID(),
            platform: .ios
        )
    }
}
