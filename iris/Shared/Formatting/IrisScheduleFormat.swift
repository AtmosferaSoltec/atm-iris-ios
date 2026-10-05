//
//  IrisScheduleFormat.swift
//  iris
//

import Foundation

/// Weekday and time strings for service schedules. Weekdays follow Calendar: 1 = Sunday … 7 = Saturday.
enum IrisScheduleFormat {
    private static let weekdays = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    private static let shortWeekdays = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"]

    /// "Domingo".
    static func weekday(_ weekday: Int) -> String {
        weekdays.indices.contains(weekday - 1) ? weekdays[weekday - 1] : ""
    }

    /// "Dom".
    static func shortWeekday(_ weekday: Int) -> String {
        shortWeekdays.indices.contains(weekday - 1) ? shortWeekdays[weekday - 1] : ""
    }

    /// "10:00", "9:30" (24-hour, as in Spanish).
    static func time(hour: Int, minute: Int) -> String {
        String(format: "%d:%02d", hour, minute)
    }

    /// "Domingo · 10:00".
    static func summary(_ schedule: ServiceType.Schedule) -> String {
        "\(weekday(schedule.weekday)) · \(time(hour: schedule.hour, minute: schedule.minute))"
    }
}
