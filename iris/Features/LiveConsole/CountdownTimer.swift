//
//  CountdownTimer.swift
//  iris
//

import Foundation

/// A countdown for sermons, games and the like. Pure state machine: it measures with the clock it is given,
/// so a UI that ticks late or not at all still shows the right remaining time. Idle → running ⇄ paused → finished.
nonisolated struct CountdownTimer: Equatable, Sendable {
    static let maxMinutes = 600

    private var remainingAtStart: TimeInterval = 0
    private var startedAt: Date?
    private(set) var isRunning = false
    private(set) var isPaused = false
    private var hasStarted = false

    /// Counting, paused or finished: anything but idle.
    var isActive: Bool { isRunning || isPaused || isFinished }

    var isIdle: Bool { !isActive }

    var isFinished: Bool { hasStarted && !isRunning && !isPaused }

    func remaining(now: Date) -> TimeInterval {
        guard hasStarted else { return 0 }
        guard isRunning, let startedAt else { return remainingAtStart }
        let left = remainingAtStart - now.timeIntervalSince(startedAt)
        return max(0, left)
    }

    /// Starts over with `duration` (clamped to 1 s … `maxMinutes` min).
    mutating func start(duration: TimeInterval, now: Date) {
        remainingAtStart = Self.clamp(duration)
        startedAt = now
        hasStarted = true
        isRunning = true
        isPaused = false
    }

    mutating func pause(now: Date) {
        guard isRunning else { return }
        remainingAtStart = remaining(now: now)
        isRunning = false
        isPaused = true
    }

    mutating func resume(now: Date) {
        guard isPaused else { return }
        startedAt = now
        isRunning = true
        isPaused = false
    }

    /// Adds time to a running, paused or finished countdown (a finished one starts running again).
    mutating func add(_ extra: TimeInterval, now: Date) {
        guard hasStarted else { return }
        let wasRunning = isRunning
        let left = remaining(now: now) + extra
        remainingAtStart = Self.clamp(left)
        startedAt = now
        if wasRunning || isFinished {
            isRunning = true
            isPaused = false
        }
    }

    mutating func stop() {
        hasStarted = false
        isRunning = false
        isPaused = false
        remainingAtStart = 0
        startedAt = nil
    }

    /// Marks a running countdown as finished once it reaches zero. Returns `true` when it just finished.
    @discardableResult
    mutating func tick(now: Date) -> Bool {
        guard isRunning, remaining(now: now) <= 0 else { return false }
        remainingAtStart = 0
        isRunning = false
        return true
    }

    /// "05:00", "00:09"; "1:05:00" from one hour. Rounds up, so the display never shows 00:00 before the end.
    static func format(_ remaining: TimeInterval) -> String {
        let seconds = Int(max(0, remaining).rounded(.up))
        let hours = seconds / 3600
        let minutes = seconds % 3600 / 60
        let rest = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%02d:%02d", minutes, rest)
    }

    private static func clamp(_ value: TimeInterval) -> TimeInterval {
        min(max(value, 1), TimeInterval(maxMinutes * 60))
    }
}
