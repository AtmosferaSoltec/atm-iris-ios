//
//  SyncIndicatorModel.swift
//  iris
//

import Foundation

/// Texts and tone of the sync indicator, derived from the sync state.
nonisolated struct SyncIndicatorModel: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case neutral, busy, warning, error
    }

    let title: String
    let tone: Tone
    /// Longer explanation for the popover.
    let detail: String
    let showsRetry: Bool

    init(status: SyncStatus, pendingCount: Int, now: Date) {
        switch status {
        case let .idle(lastSync):
            if let lastSync {
                let relative = Self.relative(lastSync, now: now)
                title = String(localized: "Actualizado \(relative)")
                detail = pendingCount > 0
                    ? Self.pendingText(pendingCount)
                    : String(localized: "Tu iPad tiene la última versión de la iglesia.")
            } else {
                title = String(localized: "Sin actualizar")
                detail = String(localized: "Aún no se descargó la iglesia en este iPad.")
            }
            tone = pendingCount > 0 ? .warning : .neutral
            showsRetry = false
        case .syncing:
            title = String(localized: "Actualizando…")
            detail = String(localized: "Descargando los cambios de la iglesia.")
            tone = .busy
            showsRetry = false
        case let .offline(pending):
            title = pending > 0
                ? String(localized: "Sin conexión · \(Self.pendingText(pending))")
                : String(localized: "Sin conexión")
            detail = String(localized: "Sigues trabajando con la copia de este iPad. Los cambios se enviarán cuando vuelva la conexión.")
            tone = .warning
            showsRetry = true
        case let .failed(message):
            title = String(localized: "No se pudo actualizar")
            detail = message
            tone = .error
            showsRetry = true
        }
    }

    /// "1 cambio pendiente", "3 cambios pendientes".
    static func pendingText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 cambio pendiente") : String(localized: "\(count) cambios pendientes")
    }

    /// "hace 2 min", "ahora".
    private static func relative(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 { return String(localized: "ahora") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
