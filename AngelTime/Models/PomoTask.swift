import Foundation

/// A to-do item that pomodoros are spent on.
struct PomoTask: Identifiable, Codable, Equatable, Hashable {
    static let estimateRange = 1...99

    var id = UUID()
    var title: String
    var note = ""
    /// How many pomodoros the user expects this task to take.
    var estimatedPomodoros = 1
    /// How many pomodoros have actually been spent on it.
    var completedPomodoros = 0
    var isDone = false
    var createdAt = Date()
    var completedAt: Date?
}
