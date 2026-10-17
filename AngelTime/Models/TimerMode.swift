import Foundation

/// The three kinds of session a Pomodoro cycle is made of.
enum TimerMode: String, CaseIterable, Codable, Identifiable {
    case pomodoro
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pomodoro: "Pomodoro"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    /// The line shown under the timer when no task is selected (same wording as pomofocus).
    var message: String {
        self == .pomodoro ? "Time to focus!" : "Time for a break!"
    }

    var isBreak: Bool { self != .pomodoro }

    /// SF Symbol used in the menu bar for this mode.
    var symbolName: String {
        self == .pomodoro ? "timer" : "cup.and.saucer.fill"
    }
}
