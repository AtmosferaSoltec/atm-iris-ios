//
//  IrisDurationFormat.swift
//  iris
//

import Foundation

/// Consistent duration strings across the app.
nonisolated enum IrisDurationFormat {
    /// "9:40", "1:32:10".
    static func clock(_ seconds: TimeInterval) -> String {
        let duration = Duration.seconds(max(0, seconds.rounded()))
        return seconds >= 3_600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond))
    }

    /// "+4:05" for overtime, "" when on time.
    static func overtime(_ seconds: TimeInterval) -> String {
        seconds > 0 ? "+\(clock(seconds))" : ""
    }

    /// "4 bloques · 1 h y 10 min", "1 bloque · 10 min".
    static func blocksSummary(count: Int, seconds: TimeInterval) -> String {
        let total = summary(seconds)
        return count == 1 ? String(localized: "1 bloque · \(total)") : String(localized: "\(count) bloques · \(total)")
    }

    /// "1 h 10 min", "45 min".
    static func summary(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated).locale(Locale(identifier: "es"))
        )
    }
}
