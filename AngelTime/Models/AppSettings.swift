import SwiftUI
import Observation

/// A one-click set of session lengths offered in Settings.
struct DurationPreset: Identifiable, Hashable {
    let name: String
    let pomodoro: Int
    let shortBreak: Int
    let longBreak: Int

    var id: String { name }
    var label: String { "\(pomodoro) · \(shortBreak) · \(longBreak)" }

    static let all = [
        DurationPreset(name: "Classic", pomodoro: 25, shortBreak: 5, longBreak: 15),
        DurationPreset(name: "Extended", pomodoro: 50, shortBreak: 10, longBreak: 20),
        DurationPreset(name: "Deep Work", pomodoro: 90, shortBreak: 15, longBreak: 30),
    ]
}

enum ReminderOption: Int, CaseIterable, Identifiable {
    case off = 0
    case oneMinute = 1
    case twoMinutes = 2
    case fiveMinutes = 5

    var id: Int { rawValue }
    var label: String { self == .off ? "Off" : "\(rawValue) min before the end" }
}

/// All user preferences. Every property is written to UserDefaults as soon as it changes.
@Observable
@MainActor
final class AppSettings {
    static let pomodoroRange = 1...180
    static let shortBreakRange = 1...60
    static let longBreakRange = 1...120
    static let longBreakIntervalRange = 1...12
    static let alarmRepeatRange = 1...5
    static let noSound = "None"

    enum Default {
        static let pomodoro = 25
        static let shortBreak = 5
        static let longBreak = 15
        static let longBreakInterval = 4
        static let alarmSound = "Glass"
        static let alarmVolume = 0.7
        static let alarmRepeat = 1
    }

    private enum Key {
        static let pomodoro = "timer.pomodoroMinutes"
        static let shortBreak = "timer.shortBreakMinutes"
        static let longBreak = "timer.longBreakMinutes"
        static let longBreakInterval = "timer.longBreakInterval"
        static let autoStartBreaks = "timer.autoStartBreaks"
        static let autoStartPomodoros = "timer.autoStartPomodoros"
        static let autoCheckTasks = "tasks.autoCheck"
        static let checkToBottom = "tasks.checkToBottom"
        static let alarmSound = "sound.alarm"
        static let alarmVolume = "sound.volume"
        static let alarmRepeat = "sound.repeat"
        static let notifyOnEnd = "notifications.onEnd"
        static let reminderMinutes = "notifications.reminderMinutes"
        static let showTimeInMenuBar = "appearance.showTimeInMenuBar"
        static let pomodoroColor = "appearance.color.pomodoro"
        static let shortBreakColor = "appearance.color.shortBreak"
        static let longBreakColor = "appearance.color.longBreak"
        static let tasksWindowOnTop = "general.tasksWindowOnTop"
        static let showInDock = "general.showInDock"

        static let all = [
            pomodoro, shortBreak, longBreak, longBreakInterval, autoStartBreaks, autoStartPomodoros,
            autoCheckTasks, checkToBottom, alarmSound, alarmVolume, alarmRepeat, notifyOnEnd,
            reminderMinutes, showTimeInMenuBar, pomodoroColor, shortBreakColor, longBreakColor,
            tasksWindowOnTop, showInDock,
        ]
    }

    @ObservationIgnored private let defaults: UserDefaults

    // MARK: Timer

    var pomodoroMinutes: Int { didSet { defaults.set(pomodoroMinutes, forKey: Key.pomodoro) } }
    var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: Key.shortBreak) } }
    var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: Key.longBreak) } }
    var longBreakInterval: Int { didSet { defaults.set(longBreakInterval, forKey: Key.longBreakInterval) } }
    var autoStartBreaks: Bool { didSet { defaults.set(autoStartBreaks, forKey: Key.autoStartBreaks) } }
    var autoStartPomodoros: Bool { didSet { defaults.set(autoStartPomodoros, forKey: Key.autoStartPomodoros) } }

    // MARK: Tasks

    /// Mark the active task done once its actual pomodoros reach the estimate.
    var autoCheckTasks: Bool { didSet { defaults.set(autoCheckTasks, forKey: Key.autoCheckTasks) } }
    /// Move checked tasks to the bottom of the list.
    var checkToBottom: Bool { didSet { defaults.set(checkToBottom, forKey: Key.checkToBottom) } }

    // MARK: Sound

    var alarmSound: String { didSet { defaults.set(alarmSound, forKey: Key.alarmSound) } }
    var alarmVolume: Double { didSet { defaults.set(alarmVolume, forKey: Key.alarmVolume) } }
    var alarmRepeat: Int { didSet { defaults.set(alarmRepeat, forKey: Key.alarmRepeat) } }

    // MARK: Notifications

    var notifyOnEnd: Bool { didSet { defaults.set(notifyOnEnd, forKey: Key.notifyOnEnd) } }
    /// Minutes before the end of a session to send a reminder. 0 turns it off.
    var reminderMinutes: Int { didSet { defaults.set(reminderMinutes, forKey: Key.reminderMinutes) } }

    // MARK: Appearance

    var showTimeInMenuBar: Bool { didSet { defaults.set(showTimeInMenuBar, forKey: Key.showTimeInMenuBar) } }
    var pomodoroColorID: String { didSet { defaults.set(pomodoroColorID, forKey: Key.pomodoroColor) } }
    var shortBreakColorID: String { didSet { defaults.set(shortBreakColorID, forKey: Key.shortBreakColor) } }
    var longBreakColorID: String { didSet { defaults.set(longBreakColorID, forKey: Key.longBreakColor) } }

    // MARK: General

    var tasksWindowOnTop: Bool { didSet { defaults.set(tasksWindowOnTop, forKey: Key.tasksWindowOnTop) } }
    var showInDock: Bool { didSet { defaults.set(showInDock, forKey: Key.showInDock) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pomodoroMinutes = defaults.int(Key.pomodoro, Default.pomodoro).clamped(to: Self.pomodoroRange)
        shortBreakMinutes = defaults.int(Key.shortBreak, Default.shortBreak).clamped(to: Self.shortBreakRange)
        longBreakMinutes = defaults.int(Key.longBreak, Default.longBreak).clamped(to: Self.longBreakRange)
        longBreakInterval = defaults.int(Key.longBreakInterval, Default.longBreakInterval)
            .clamped(to: Self.longBreakIntervalRange)
        autoStartBreaks = defaults.bool(Key.autoStartBreaks, false)
        autoStartPomodoros = defaults.bool(Key.autoStartPomodoros, false)
        autoCheckTasks = defaults.bool(Key.autoCheckTasks, false)
        checkToBottom = defaults.bool(Key.checkToBottom, true)
        alarmSound = defaults.string(forKey: Key.alarmSound) ?? Default.alarmSound
        alarmVolume = defaults.double(Key.alarmVolume, Default.alarmVolume).clamped(to: 0...1)
        alarmRepeat = defaults.int(Key.alarmRepeat, Default.alarmRepeat).clamped(to: Self.alarmRepeatRange)
        notifyOnEnd = defaults.bool(Key.notifyOnEnd, true)
        reminderMinutes = ReminderOption(rawValue: defaults.int(Key.reminderMinutes, 0))?.rawValue ?? 0
        showTimeInMenuBar = defaults.bool(Key.showTimeInMenuBar, true)
        pomodoroColorID = defaults.colorID(Key.pomodoroColor, for: .pomodoro)
        shortBreakColorID = defaults.colorID(Key.shortBreakColor, for: .shortBreak)
        longBreakColorID = defaults.colorID(Key.longBreakColor, for: .longBreak)
        tasksWindowOnTop = defaults.bool(Key.tasksWindowOnTop, false)
        showInDock = defaults.bool(Key.showInDock, false)
    }

    // MARK: Durations

    static func range(for mode: TimerMode) -> ClosedRange<Int> {
        switch mode {
        case .pomodoro: pomodoroRange
        case .shortBreak: shortBreakRange
        case .longBreak: longBreakRange
        }
    }

    func minutes(for mode: TimerMode) -> Int {
        switch mode {
        case .pomodoro: pomodoroMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
    }

    /// Sets a session length, clamped to the allowed range for that mode.
    func setMinutes(_ minutes: Int, for mode: TimerMode) {
        let value = minutes.clamped(to: Self.range(for: mode))
        switch mode {
        case .pomodoro: pomodoroMinutes = value
        case .shortBreak: shortBreakMinutes = value
        case .longBreak: longBreakMinutes = value
        }
    }

    func duration(for mode: TimerMode) -> TimeInterval {
        TimeInterval(minutes(for: mode) * 60)
    }

    func apply(_ preset: DurationPreset) {
        setMinutes(preset.pomodoro, for: .pomodoro)
        setMinutes(preset.shortBreak, for: .shortBreak)
        setMinutes(preset.longBreak, for: .longBreak)
    }

    // MARK: Colors

    func colorID(for mode: TimerMode) -> String {
        switch mode {
        case .pomodoro: pomodoroColorID
        case .shortBreak: shortBreakColorID
        case .longBreak: longBreakColorID
        }
    }

    func setColorID(_ id: String, for mode: TimerMode) {
        guard ThemePalette.isValid(id: id) else { return }
        switch mode {
        case .pomodoro: pomodoroColorID = id
        case .shortBreak: shortBreakColorID = id
        case .longBreak: longBreakColorID = id
        }
    }

    func color(for mode: TimerMode) -> Color {
        ThemePalette.color(id: colorID(for: mode))
    }

    // MARK: Reset

    func resetToDefaults() {
        Key.all.forEach(defaults.removeObject(forKey:))
        let fresh = AppSettings(defaults: defaults)
        pomodoroMinutes = fresh.pomodoroMinutes
        shortBreakMinutes = fresh.shortBreakMinutes
        longBreakMinutes = fresh.longBreakMinutes
        longBreakInterval = fresh.longBreakInterval
        autoStartBreaks = fresh.autoStartBreaks
        autoStartPomodoros = fresh.autoStartPomodoros
        autoCheckTasks = fresh.autoCheckTasks
        checkToBottom = fresh.checkToBottom
        alarmSound = fresh.alarmSound
        alarmVolume = fresh.alarmVolume
        alarmRepeat = fresh.alarmRepeat
        notifyOnEnd = fresh.notifyOnEnd
        reminderMinutes = fresh.reminderMinutes
        showTimeInMenuBar = fresh.showTimeInMenuBar
        pomodoroColorID = fresh.pomodoroColorID
        shortBreakColorID = fresh.shortBreakColorID
        longBreakColorID = fresh.longBreakColorID
        tasksWindowOnTop = fresh.tasksWindowOnTop
        showInDock = fresh.showInDock
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension UserDefaults {
    func int(_ key: String, _ fallback: Int) -> Int {
        object(forKey: key) as? Int ?? fallback
    }

    func bool(_ key: String, _ fallback: Bool) -> Bool {
        object(forKey: key) as? Bool ?? fallback
    }

    func double(_ key: String, _ fallback: Double) -> Double {
        object(forKey: key) as? Double ?? fallback
    }

    func colorID(_ key: String, for mode: TimerMode) -> String {
        if let id = string(forKey: key), ThemePalette.isValid(id: id) { return id }
        return ThemePalette.defaultID(for: mode)
    }
}
